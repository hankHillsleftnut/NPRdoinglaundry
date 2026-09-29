import { ALL_EDGES } from './nodes';

// ---------------------------------------------------------------------------
// "What path is this step on?"
//
// Answered by walking edges in both directions from the clicked node: every
// step that feeds it, and every step it feeds. The hop distance is kept so the
// canvas can fade the path out as it gets further away -- near neighbours read
// brightest, the far ends of the chain sink back toward the background.
// ---------------------------------------------------------------------------

type Adjacency = Map<string, string[]>;

let forward: Adjacency | null = null;
let backward: Adjacency | null = null;

function build() {
  if (forward && backward) return;
  forward = new Map();
  backward = new Map();
  for (const e of ALL_EDGES) {
    if (!forward.has(e.from)) forward.set(e.from, []);
    forward.get(e.from)!.push(e.to);
    if (!backward.has(e.to)) backward.set(e.to, []);
    backward.get(e.to)!.push(e.from);
  }
}

function walk(start: string, adj: Adjacency, out: Map<string, number>) {
  const queue: [string, number][] = [[start, 0]];
  const seen = new Set<string>([start]);
  while (queue.length) {
    const [id, depth] = queue.shift()!;
    const prev = out.get(id);
    if (prev === undefined || depth < prev) out.set(id, depth);
    for (const next of adj.get(id) ?? []) {
      if (seen.has(next)) continue;
      seen.add(next);
      queue.push([next, depth + 1]);
    }
  }
}

/**
 * Every node reachable from `id` in either direction, mapped to its hop
 * distance. The node itself is depth 0. Returns null when nothing is selected,
 * which the canvas reads as "no path, show everything normally".
 */
export function pathFrom(id: string | null): Map<string, number> | null {
  if (!id) return null;
  build();
  const out = new Map<string, number>();
  out.set(id, 0);
  walk(id, forward!, out);
  walk(id, backward!, out);
  return out;
}

/** True when this edge joins two nodes that are both on the highlighted path. */
export function edgeOnPath(
  path: Map<string, number> | null,
  from: string,
  to: string,
): boolean {
  if (!path) return false;
  return path.has(from) && path.has(to);
}
