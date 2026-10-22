import { z } from 'zod';

/**
 * Guesses (contract 02 §4) from the agent's hypotheses routes
 * (`GET /hypotheses/:userId/pending`, `GET …/:id/why`, `POST …/:id`).
 *
 * The agent keeps ids and reports `stored` as `offered`; the door maps the
 * evidence kinds onto contract 02's `SourceRef.kind` (`why` → `pattern`,
 * `fact` → `fact`) and drops any guess whose status the contract doesn't
 * know (logged as a count), so the phone never shows a status it can't name.
 */

export const GUESS_STATUSES = ['offered', 'confirmed', 'declined', 'expired'] as const;
export type GuessStatus = (typeof GUESS_STATUSES)[number];
/** What answering can come back as (pass F10: a guess retired between load and answer is `expired`). */
export const ANSWER_STATUSES = ['confirmed', 'declined', 'expired'] as const;

const SOURCE_KINDS = ['entry', 'fact', 'answer', 'pattern', 'saved', 'turn'] as const;

export const EvidenceOut = z.object({
  kind: z.string().min(1),
  id: z.string().min(1),
  label: z.string().optional(),
  text: z.string(),
}).strict();

export const GuessOut = z.object({
  id: z.string().uuid(),
  question: z.string().min(1),
  framework: z.object({ name: z.string().min(1), source: z.string().optional(), wonders: z.string().optional() }).strict(),
  rationale: z.string().optional(),
  status: z.enum(GUESS_STATUSES),
  restsOn: z.array(EvidenceOut),
}).strict();

export const GuessesOut = z.object({ guesses: z.array(GuessOut), speaking: z.boolean() }).strict();
export const AnswerOut = z.object({ status: z.enum(ANSWER_STATUSES) }).strict();

export type Guess = z.infer<typeof GuessOut>;

/** What the agent's pending and why routes answer, as far as the door reads it. */
export interface AgentGuess {
  id: string;
  question: string;
  framework: { name: string; source?: string | null; wonders?: string | null };
  rationale?: string | null;
  status: string;
  restsOn: Array<{ kind: string; id: string; text?: string | null }>;
}

/** The agent's claim kinds as the contract names them. Unknown kinds pass through: the phone shows `unknown`, the text still reads. */
export function sourceKind(kind: string): string {
  if (kind === 'why') return 'pattern';
  if (kind === 'item') return 'entry';
  if (kind === 'said_today') return 'turn';
  return (SOURCE_KINDS as readonly string[]).includes(kind) ? kind : kind;
}

export function isGuessStatus(s: string): s is GuessStatus {
  return (GUESS_STATUSES as readonly string[]).includes(s);
}

/** One guess for the app, or null when its status is one the contract doesn't have. */
export function mapGuess(g: AgentGuess): Guess | null {
  if (!isGuessStatus(g.status)) return null;
  return {
    id: g.id,
    question: g.question,
    framework: {
      name: g.framework.name,
      ...(g.framework.source ? { source: g.framework.source } : {}),
      ...(g.framework.wonders ? { wonders: g.framework.wonders } : {}),
    },
    ...(g.rationale ? { rationale: g.rationale } : {}),
    status: g.status,
    restsOn: (g.restsOn ?? []).map((e) => ({ kind: sourceKind(e.kind), id: e.id, text: e.text ?? '' })),
  };
}
