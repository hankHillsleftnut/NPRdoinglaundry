import type { Router } from 'express';
import { z } from 'zod';
import type { DoorFactory } from '../doors/door.js';
import { DoorError } from '../doors/errors.js';
import type { GuessStore } from './store.js';
import { mapGuess, type AgentGuess, type Guess } from './map.js';

/**
 * The guess cards (BE1.4; contract 02 §4, BE1.3-BE1.4 pass §1.5-§1.6):
 *   GET  /v2/guesses          { guesses, speaking }   the open guesses, newest first
 *   GET  /v2/guesses/:id/why  Guess                   why Retro thinks that (a bare Guess, as the app decodes it)
 *   POST /v2/guesses/:id      { status }              "yes" or "no"
 * The list and the why go through the brain (`restsOn` text needs the
 * contract); ownership and the stored status are read from the shared
 * database first, so another person's id is `not_found` before the brain is
 * called, and a repeat answer returns the stored status without calling it.
 */
export interface GuessDoorDeps {
  guesses: GuessStore;
}

const Empty = z.object({}).strict();
const ById = z.object({ id: z.string().uuid() }).strict();
const AnswerBody = z.object({ id: z.string().uuid(), verdict: z.enum(['yes', 'no']) }).strict();

const AGENT = { timeoutMs: 10_000 } as const;
/** The statuses an answer comes back as; anything else the agent could store is treated as still open. */
const SETTLED = new Set(['confirmed', 'declined', 'expired']);

export function mountGuessDoors(router: Router, door: DoorFactory, deps: GuessDoorDeps): void {
  const owns = async (ctx: { userId: string }, req: { id: string }) => (await deps.guesses.find(req.id))?.userId === ctx.userId;

  router.get('/guesses', door({
    name: 'guesses.list',
    bucket: 'read',
    request: Empty,
    call: async (ctx) => {
      const r = await ctx.agent.get<{ speaking?: unknown; guesses?: AgentGuess[] }>(`/hypotheses/${ctx.userId}/pending`, { ...AGENT, retry: 'read' });
      const speaking = r.speaking === true;
      const guesses: Guess[] = [];
      let dropped = 0;
      for (const g of speaking ? (r.guesses ?? []) : []) {
        const guess = mapGuess(g);
        if (guess) guesses.push(guess);
        else dropped++;
      }
      return { guesses, speaking, dropped };
    },
    map: (r) => ({ guesses: r.guesses, speaking: r.speaking }),
    // A guess with a status the contract has no name for is left out and counted in the door log, beside the other metrics.
    logCounts: (r) => (r.dropped ? { dropped: r.dropped } : {}),
  }));

  router.get('/guesses/:id/why', door({
    name: 'guesses.why',
    bucket: 'read',
    request: ById,
    owns,
    call: (ctx, req) => ctx.agent.get<AgentGuess>(`/hypotheses/${ctx.userId}/${req.id}/why`, { ...AGENT, retry: 'read' }),
    map: (g) => {
      const guess = mapGuess(g);
      if (!guess) throw new DoorError('not_found');
      return guess;
    },
  }));

  router.post('/guesses/:id', door({
    name: 'guesses.answer',
    bucket: 'write',
    request: AnswerBody,
    owns,
    call: async (ctx, req) => {
      // The stored status is the truth: an answered or retired guess is returned as it is, and
      // the brain is not called (it would 404 on a repeat). Two devices: the first to land wins.
      const row = await deps.guesses.find(req.id);
      if (!row || row.userId !== ctx.userId) throw new DoorError('not_found');
      if (SETTLED.has(row.status)) return { status: row.status, repeated: true };
      const answered = await ctx.agent.post<{ status?: unknown }>(`/hypotheses/${ctx.userId}/${req.id}`, { verdict: req.verdict }, { ...AGENT, retry: 'none' });
      if (typeof answered.status !== 'string' || !SETTLED.has(answered.status)) throw new Error('guesses.answer: the agent answered without a status');
      return { status: answered.status, repeated: false };
    },
    map: (r) => ({ status: r.status }),
  }));
}
