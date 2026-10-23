import { z } from 'zod';
import type { SignedLink } from '../briefs/map.js';
import { EpisodeSummaryOut, episodeSummary } from './map.js';
import { scriptLines } from './split.js';
import type { EpisodeDetailRow } from './store.js';

/**
 * One episode as contract 03 §3 shows it, legacy shape (BE3.x.ep): the
 * summary, the script as lines (paragraphs then sentences, no times, no
 * chapters, register `craft`), no chapters, claims or "made from" until the
 * brain stores sections (BE3.0a, BE3.x.ep2), and the private audio link when
 * there is one. Pure: the door passes the row and the link in.
 */

const SOURCE_KINDS = ['entries', 'voice', 'calendar', 'health', 'steps', 'sleep', 'saved', 'watched', 'listened', 'mail', 'unknown'] as const;

export const LineOut = z.object({
  index: z.number().int().min(0),
  text: z.string().min(1),
  chapterIndex: z.number().int().min(-1),
  startSeconds: z.number().min(0).optional(),
  register: z.enum(['stated', 'asked', 'craft']),
  claimId: z.string().optional(),
}).strict();

export const ChapterOut = z.object({
  index: z.number().int().min(0),
  title: z.string(),
  startSeconds: z.number().min(0),
  claimId: z.string().optional(),
}).strict();

export const ClaimSummaryOut = z.object({
  id: z.string(),
  kind: z.enum(['pattern', 'answer', 'why', 'hypothesis', 'shift', 'goal', 'content', 'unknown']),
  register: z.enum(['stated', 'asked']),
  chapterIndex: z.number().int(),
  guessId: z.string().optional(),
}).strict();

export const EpisodeAudioOut = z.object({
  url: z.string().url(),
  expiresAt: z.string().datetime(),
  durationSeconds: z.number().min(0),
  bytes: z.number().int().positive().optional(),
  mimeType: z.literal('audio/mpeg'),
}).strict();

export const EpisodeOut = EpisodeSummaryOut.extend({
  madeFrom: z.array(z.object({ kind: z.enum(SOURCE_KINDS), count: z.number().int().positive() }).strict()),
  chapters: z.array(ChapterOut),
  lines: z.array(LineOut),
  description: z.string().optional(),
  claims: z.array(ClaimSummaryOut),
  audio: EpisodeAudioOut.optional(),
  /** The person's last feedback; never set by this door (feedback is not built yet). */
  feedback: z.object({ verdict: z.enum(['more', 'less']).nullable(), at: z.string().datetime() }).strict().optional(),
}).strict();

export const EpisodeByIdOut = z.object({ episode: EpisodeOut }).strict();

export type Episode = z.infer<typeof EpisodeOut>;
export type Line = z.infer<typeof LineOut>;

/** The contract's legacy `lines`: every sentence of the script, in order, outside any chapter. */
export function legacyLines(script: string): Line[] {
  return scriptLines(script).map((text, index) => ({ index, text, chapterIndex: -1, register: 'craft' as const }));
}

/**
 * The contract's `Episode`. `hasAudio` says whether this answer carries a link:
 * a row with a file whose link storage refused reads as words only, so the
 * app never sees `hasAudio: true` without `audio`.
 * `unknown` says the generation type had no contract name (counted in the log).
 */
export function episodeResponse(row: EpisodeDetailRow, link: SignedLink | null): { episode: Episode; unknown: boolean } {
  const { summary, unknown } = episodeSummary(row);
  const lines = legacyLines(row.script);
  return {
    episode: {
      ...summary,
      hasAudio: link !== null,
      madeFrom: [],
      chapters: [],
      lines,
      // Only when there is nothing to read along with (contract 03 §3).
      ...(lines.length === 0 && row.description ? { description: row.description } : {}),
      claims: [],
      ...(link ? { audio: { url: link.url, expiresAt: link.expiresAt, durationSeconds: summary.durationSeconds, mimeType: 'audio/mpeg' as const } } : {}),
    },
    unknown,
  };
}
