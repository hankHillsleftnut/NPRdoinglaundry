import { createHash } from 'node:crypto';
import { z } from 'zod';

/**
 * First run's answers, pure (BE2.2b.min, contract 01 §1 and §4): the closed
 * list of question keys in the order the questions are asked, the line each
 * question is asked with, the request schema, and the person's profile composed
 * from their latest answer per key.
 *
 * Why a composed profile: the brain's first pass reads only the newest
 * `onboarding_profile` row (agent src/questions/run-first-pass.ts,
 * POOL_LIMITS.onboarding = 1), and that type is already "the person's own
 * words" (agent src/brain/trust.ts, trigger 126). One row per answer alone
 * would leave the first episode seeing one answer.
 */

/** Contract 01 §1's QuestionKey, without `unknown`, in the order the questions are asked (the profile's order). */
export const QUESTION_KEYS = [
  'name.place', 'year.from.now', 'care.most', 'on.your.mind', 'working.on', 'keep.meaning', 'high.low', 'people',
  'how.straight', 'yesterday', 'reading.watching', 'this.week',
] as const;
export type QuestionKey = (typeof QUESTION_KEYS)[number];

/**
 * The line each question is asked with, for the profile only: the app owns the
 * copy it shows and never sends it. The 8 core lines are the app's
 * (Platform/Flows/FirstRun.swift, P02.min); `this.week` is ON-10's
 * (docs/team/flows/first-run/views.md); the rest are
 * docs/second-brain/brief-onboarding-questions.md's, lower-cased the same way.
 */
export const QUESTION_LINES: Readonly<Record<QuestionKey, string>> = {
  'name.place': 'first, what should i call you, and where are you based?',
  'year.from.now': 'picture a year from now, and everything has gone as well as it realistically could. what does your life look like?',
  'care.most': "what do you care about most: the things you'd protect even if they cost you?",
  'on.your.mind': "what's been taking up most of your head lately?",
  'working.on': 'what are you working on right now, and how is it actually going?',
  'keep.meaning': "what's one thing you keep meaning to change, and what's gotten in the way so far?",
  'high.low': 'a high point and a low point from the last few months?',
  people: 'who would you call if something went wrong? anyone you wish you saw more?',
  'how.straight': 'how should i talk to you: straight or gentle, push you or let you be?',
  yesterday: "walk me through yesterday: what you did, who you saw, what you'd have skipped.",
  'reading.watching': 'what have you been reading, watching or learning lately, by choice?',
  'this.week': "while i get your first episode ready: what's one thing you want this week to go well?",
};

/** Contract 01 §1's Given, without `unknown` (a client never sends it). */
export const GIVEN = ['voice', 'typed', 'skipped'] as const;
export type Given = (typeof GIVEN)[number];

/** 0–8,000 UTF-16 code units after trimming (contract 01 §4; zod counts UTF-16 as Swift does). */
export const MAX_ANSWER_UNITS = 8_000;
/** A createdAt older than this is refused (contract 01 §4). */
export const MAX_ANSWER_AGE_MS = 30 * 24 * 60 * 60_000;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
/** Postgres text can't hold NUL: the client's mistake, not a server error. */
const noNul = (s: string) => !s.includes('\u0000');

/**
 * Fixtures 01/answer.create.request*.json. Strict: a client-sent userId or any
 * other field is invalid_request. `""` only with `given: "skipped"`, and a
 * skipped answer carries no words.
 */
export const AnswerCreateBody = z.object({
  questionKey: z.enum(QUESTION_KEYS),
  text: z.string().transform((s) => s.trim()).pipe(z.string().max(MAX_ANSWER_UNITS).refine(noNul)),
  given: z.enum(GIVEN),
  clientEntryId: z.string().regex(UUID),
  /** ISO 8601, UTC with a Z (an offset is invalid_request, as on entries). */
  createdAt: z.string().datetime().refine((s) => !Number.isNaN(Date.parse(s))),
}).strict().refine((b) => (b.given === 'skipped') === (b.text === ''));
export type AnswerCreateBody = z.infer<typeof AnswerCreateBody>;

/** One answer as the profile reads it. */
export interface ProfileAnswer {
  id: string;
  questionKey: QuestionKey;
  given: Given;
  text: string;
  /** When the row was stored (raw_content.created_at), when known. */
  arrivedAt?: string;
}

/**
 * The most of the profile the brain's episode prompt reads (agent
 * src/pipelines/podcast.ts formatOnboardingFoundation: `content.slice(0, 8000)`,
 * UTF-16 units). The profile is fitted to it so a long early answer can't push
 * the later ones (this.week, the one the first episode leans on) out unseen.
 * The answer rows keep every word.
 */
export const PROFILE_BUDGET_UNITS = 8_000;
const CLIPPED = '…';

/** The first code points of `s` that fit in `units` UTF-16 units (never half an emoji). */
function clipUnits(s: string, units: number): string {
  let out = '';
  for (const cp of s) {
    if (out.length + cp.length > units) break;
    out += cp;
  }
  return out;
}

/**
 * The cap per answer so that every answer fits in `room` units: short answers
 * whole, long ones sharing what is left equally (water-filling). Infinity when
 * everything already fits.
 */
function fairCap(lengths: readonly number[], room: number): number {
  if (lengths.reduce((s, n) => s + n, 0) <= room) return Infinity;
  const sorted = [...lengths].sort((a, b) => a - b);
  let left = room;
  for (let i = 0; i < sorted.length; i++) {
    const share = Math.floor(left / (sorted.length - i));
    if (sorted[i]! > share) return Math.max(0, share);
    left -= sorted[i]!;
  }
  return Infinity;
}

/**
 * The person's profile: for each key in QUESTION_KEYS order, the question line
 * and their answer, as two lines; blocks apart by a blank line; fitted to
 * PROFILE_BUDGET_UNITS (a clipped answer ends in "…"). `latest` must already be
 * the latest answer per key (the store's job); a skipped or empty answer is
 * left out. Empty text when nothing has words. `newestArrival` is the latest
 * arrival among the answers used: the profile row is stamped with it, so of two
 * profiles composed at once, the one that saw more answers reads as newest.
 */
export function composeProfile(latest: readonly ProfileAnswer[]): { text: string; answerIds: string[]; newestArrival: string | null } {
  const byKey = new Map(latest.map((a) => [a.questionKey, a]));
  const used: { key: QuestionKey; text: string; a: ProfileAnswer }[] = [];
  for (const key of QUESTION_KEYS) {
    const a = byKey.get(key);
    if (!a || a.given === 'skipped' || a.text.trim() === '') continue;
    used.push({ key, text: a.text.trim(), a });
  }
  // Fixed cost: each question line, its newline, and the blank line between blocks.
  const fixed = used.reduce((s, u) => s + QUESTION_LINES[u.key].length + 1, 0) + Math.max(0, used.length - 1) * 2;
  const cap = fairCap(used.map((u) => u.text.length), PROFILE_BUDGET_UNITS - fixed);
  const blocks = used.map((u) => {
    const text = u.text.length <= cap ? u.text : `${clipUnits(u.text, Math.max(0, cap - CLIPPED.length))}${CLIPPED}`;
    return `${QUESTION_LINES[u.key]}\n${text}`;
  });
  const arrivals = used.map((u) => u.a.arrivedAt).filter((t): t is string => typeof t === 'string').sort();
  return { text: blocks.join('\n\n'), answerIds: used.map((u) => u.a.id), newestArrival: arrivals[arrivals.length - 1] ?? null };
}

/**
 * The profile row's explicit idempotency key: the composed text and the answer
 * rows it was made from. A retry composes the same thing and gets the same key
 * (never a second row); answering again always makes a new key, even when the
 * words come back to an earlier version (the brain reads the newest row, so an
 * older copy of the same text must not be what stays newest).
 */
export function profileKey(answerIds: readonly string[], text: string): string {
  return createHash('sha256').update(answerIds.join(',')).update('\0').update(text).digest('hex');
}

/** What an answer's Idempotency-Key fingerprints (never createdAt, so clamping skew can't turn a retry into a mismatch). */
export function answerFingerprint(a: { questionKey: string; given: string; text: string }): string {
  return JSON.stringify([a.questionKey, a.given, a.text]);
}
