import type { Router } from 'express';
import { z } from 'zod';
import type { DoorFactory } from '../doors/door.js';
import { DoorError } from '../doors/errors.js';
import { ACCESS_STATES } from '../access/store.js';
import { CLOCK_SKEW_MS } from '../entries/doors.js';
import { AnswerCreateBody, GIVEN, MAX_ANSWER_AGE_MS, QUESTION_KEYS, composeProfile, profileKey } from './profile.js';
import type { OnboardingStore, StoredAnswer } from './store.js';

/**
 * First run's doors (BE2.2b.min, contract 01 §3 and §4):
 *   POST /v2/onboarding/answers   one answer, once (Idempotency-Key = clientEntryId)
 *   POST /v2/onboarding/complete  approved -> member, idempotent
 * Neither calls the brain while answering. A new answer re-composes the
 * person's profile (their latest answer per key, as question line + answer)
 * into one `onboarding_profile` row, and THAT row is handed to ingest after
 * the response; the answer row itself is never ingested (store.ts). Nothing
 * here is open to waitlisted people. The log line carries the door, the user,
 * the status and the time: never the words, never a question's line.
 */
export interface OnboardingDoorDeps {
  onboarding: OnboardingStore;
  /** Starts the brain's read of one stored row, after the response; never throws into the door. */
  startIngest: (userId: string, rawContentId: string) => void;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Contract 01 §1's Answer (fixture 01/answer.create.response.json). */
export const Answer = z.object({
  id: z.string().regex(UUID),
  questionKey: z.enum([...QUESTION_KEYS, 'unknown'] as const),
  text: z.string(),
  given: z.enum([...GIVEN, 'unknown'] as const),
  createdAt: z.string().datetime(),
}).strict();
export type Answer = z.infer<typeof Answer>;
export const AnswerResponse = z.object({ answer: Answer }).strict();
/** Fixture 01/onboarding.complete.response.json. */
export const CompleteResponse = z.object({ access: z.object({ state: z.enum(ACCESS_STATES) }).strict() }).strict();
export type CompleteResponse = z.infer<typeof CompleteResponse>;

const Empty = z.object({}).strict();

export function toAnswer(a: StoredAnswer): Answer {
  return { id: a.id, questionKey: a.questionKey, text: a.text, given: a.given, createdAt: a.createdAt };
}

export function mountOnboardingDoors(router: Router, door: DoorFactory, deps: OnboardingDoorDeps): void {
  // One answer. Once per clientEntryId: the header must be the body's id
  // (lower-cased both sides), the fingerprint is key + given + text (never
  // createdAt), a replay answers with the stored row. Then the profile is
  // composed from the caller's rows only and stored once per composition; a
  // replay composes too, so an answer whose profile write failed last time
  // gets it now (and an unchanged profile is never stored twice).
  router.post('/onboarding/answers', door({
    name: 'onboarding.answers.create',
    bucket: 'write',
    request: AnswerCreateBody,
    call: async (ctx, body) => {
      const key = ctx.idempotencyKey?.toLowerCase();
      const clientEntryId = body.clientEntryId.toLowerCase();
      if (key !== clientEntryId) throw new DoorError('invalid_request');
      const sent = Date.parse(body.createdAt);
      if (sent < ctx.now - MAX_ANSWER_AGE_MS) throw new DoorError('invalid_request');
      // The person's moment, unless their clock is ahead: then it is now, and counted.
      const skewed = sent > ctx.now + CLOCK_SKEW_MS;
      const saved = await deps.onboarding.saveAnswer({
        userId: ctx.userId, clientEntryId, questionKey: body.questionKey, given: body.given, text: body.text,
        createdAtIso: new Date(skewed ? ctx.now : sent).toISOString(), appVersion: ctx.appVersion,
      });
      if (saved.outcome === 'mismatch') throw new DoorError('idempotency_mismatch');

      const profile = composeProfile(await deps.onboarding.latestAnswers(ctx.userId));
      if (profile.text !== '') {
        const stored = await deps.onboarding.saveProfile({
          userId: ctx.userId, text: profile.text, key: profileKey(profile.answerIds, profile.text), answers: profile.answerIds.length,
          createdAtIso: profile.newestArrival ?? new Date(ctx.now).toISOString(), nowIso: new Date(ctx.now).toISOString(),
        });
        if (stored.created) deps.startIngest(ctx.userId, stored.id);
      }
      return { created: saved.outcome === 'created', answer: saved.answer, skewed };
    },
    map: (r) => ({ answer: toAnswer(r.answer) }),
    status: (r) => (r.created ? 201 : 200),
    // Counted once, when the answer is stored; a replay of a clamped answer is not a second skew.
    logCounts: (r) => (r.skewed && r.created ? { clockSkew: 1 } : {}),
  }));

  // The end of first run. One guarded UPDATE (only `approved` moves), so a
  // retry, or two at once, answer the same; member and staff stay as they are.
  // A waitlisted person never gets here (the gate answers invite_required).
  router.post('/onboarding/complete', door({
    name: 'onboarding.complete',
    bucket: 'write',
    request: Empty,
    call: async (ctx) => {
      const state = await deps.onboarding.complete(ctx.userId);
      if (state === null) throw new DoorError('unauthenticated');
      // The database moved under the gate (a staff pause or a reset): its answer wins.
      if (state === 'waitlisted') throw new DoorError('invite_required');
      if (state === 'suspended') throw new DoorError('suspended');
      return state;
    },
    map: (state): CompleteResponse => ({ access: { state } }),
  }));
}
