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
}

/**
 * The person's profile: for each key in QUESTION_KEYS order, the question line
 * and their answer, as two lines; blocks apart by a blank line. `latest` must
 * already be the latest answer per key (the store's job); a skipped or empty
 * answer is left out. Empty text when nothing has words.
 */
export function composeProfile(latest: readonly ProfileAnswer[]): { text: string; answerIds: string[] } {
  const byKey = new Map(latest.map((a) => [a.questionKey, a]));
  const blocks: string[] = [];
  const answerIds: string[] = [];
  for (const key of QUESTION_KEYS) {
    const a = byKey.get(key);
    if (!a || a.given === 'skipped' || a.text.trim() === '') continue;
    blocks.push(`${QUESTION_LINES[key]}\n${a.text.trim()}`);
    answerIds.push(a.id);
  }
  return { text: blocks.join('\n\n'), answerIds };
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
