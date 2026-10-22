import type { BriefDbClient } from '../briefs/store.js';

/**
 * Guesses in the shared database (BE1.4): one direct read of the agent's
 * `hypotheses` row (agent migration 149) for ownership and the stored status,
 * so the door can answer `not_found` before the brain is called and can
 * answer a repeat without calling it at all. Errors carry the database code only.
 */
export interface GuessRow {
  userId: string;
  status: string;
}

export interface GuessStore {
  /** Who owns the guess and where it stands; null when there is no such guess. */
  find(guessId: string): Promise<GuessRow | null>;
}

export function supabaseGuessStore(db: BriefDbClient): GuessStore {
  return {
    async find(guessId) {
      const r = await db.from('hypotheses').select('user_id,status').eq('id', guessId).maybeSingle();
      if (r.error) throw new Error(`guess lookup failed (${r.error.code ?? 'unknown'})`);
      if (!r.data) return null;
      const row = r.data as { user_id: string; status: string };
      return { userId: String(row.user_id), status: String(row.status) };
    },
  };
}
