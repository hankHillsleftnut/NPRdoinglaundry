/**
 * Don't store a goal the person already has (goal 7).
 *
 * Found 19 Oct: goal synthesis runs on every onboarding submission and
 * createGoal inserted unconditionally, so one person accumulated 115 goals,
 * most of them near-copies of seven. Before inserting, look for one of their
 * goals that is more than 0.9 similar (the same bar the agent's lifecycle
 * uses to merge): reuse it if it's active, revive it if it had expired or
 * been merged ("stated again" is evidence it matters).
 */

export const SAME_GOAL = 0.9;

export interface ExistingGoal { id: string; status?: string | null; is_active?: boolean | null; embedding: unknown }

export function parseEmbedding(v: unknown): number[] | null {
  if (Array.isArray(v)) return v.map(Number);
  if (typeof v === 'string' && v.startsWith('[')) return JSON.parse(v) as number[];
  return null;
}

export function cosine(a: number[], b: number[]): number {
  let dot = 0, na = 0, nb = 0;
  for (let i = 0; i < a.length; i++) { dot += a[i]! * b[i]!; na += a[i]! ** 2; nb += b[i]! ** 2; }
  return na && nb ? dot / Math.sqrt(na * nb) : 0;
}

/** The person's existing goal this one repeats, preferring an active one. Pure. */
export function findSameGoal(existing: ExistingGoal[], embedding: number[]): { goal: ExistingGoal; similarity: number } | null {
  let best: { goal: ExistingGoal; similarity: number } | null = null;
  for (const g of existing) {
    const v = parseEmbedding(g.embedding);
    if (!v) continue;
    const s = cosine(v, embedding);
    if (s <= SAME_GOAL) continue;
    const active = (g.status ?? (g.is_active === false ? 'expired' : 'active')) === 'active';
    const bestActive = best ? (best.goal.status ?? 'active') === 'active' : false;
    if (!best || (active && !bestActive) || (active === bestActive && s > best.similarity)) best = { goal: g, similarity: s };
  }
  return best;
}
