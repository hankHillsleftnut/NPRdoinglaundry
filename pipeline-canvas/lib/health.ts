import type { Health, NodeSpec, NodeState, Snapshot } from './types';

// ---------------------------------------------------------------------------
// Turning facts into a colour. Every rule here exists to stop the board
// overstating what it knows.
//
// Order matters, and the first two rules are the important ones:
//   1. a failed read is `unknown`, never green and never grey
//   2. an uninstrumented step says so, rather than borrowing a neighbour's health
// ---------------------------------------------------------------------------

const DEFAULT_FAIL = ['failed', 'dead_letter', 'error', 'errored', 'cancelled'];
const DEFAULT_WARN = ['pending', 'queued', 'running', 'stale', 'degraded', 'candidate'];

const asArray = (v: string | string[] | undefined): string[] | null =>
  v === undefined ? null : Array.isArray(v) ? v : [v];

function ago(iso: string | null): string {
  if (!iso) return 'never';
  const ms = Date.now() - new Date(iso).getTime();
  if (Number.isNaN(ms)) return 'unknown';
  const m = Math.floor(ms / 60000);
  if (m < 1) return 'just now';
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  const d = Math.floor(h / 24);
  if (d < 365) return `${d}d ago`;
  return `${Math.floor(d / 365)}y ago`;
}

export function resolveNode(spec: NodeSpec, snap: Snapshot): NodeState {
  if (spec.probe.kind === 'notInstrumented') {
    return {
      id: spec.id,
      health: 'notInstrumented',
      lastAt: null,
      lastLabel: null,
      total: 0,
      failed: 0,
      detail: spec.probe.reason,
    };
  }

  const p = spec.probe;
  const meta = snap.sources[p.source];

  // Rule 1: the read failed. We know nothing. Say nothing.
  if (!meta || meta.error) {
    return {
      id: spec.id,
      health: 'unknown',
      lastAt: null,
      lastLabel: null,
      total: 0,
      failed: 0,
      detail: meta?.error ? `read failed: ${meta.error}` : `no data for source ${p.source}`,
    };
  }

  const buckets = asArray(p.bucket);
  const facts = snap.facts.filter(
    (f) =>
      f.source === p.source &&
      (buckets === null || buckets.includes(f.bucket)) &&
      (p.only === undefined || p.only.includes(f.status)),
  );

  const failStatuses = p.failStatuses ?? DEFAULT_FAIL;
  const warnStatuses = p.warnStatuses ?? DEFAULT_WARN;

  let total = 0;
  let failed = 0;
  let warned = 0;
  let recentTotal = 0;
  let recentFailed = 0;
  let lastAt: string | null = null;
  let lastLabel: string | null = null;

  for (const f of facts) {
    total += f.n;
    recentTotal += f.recentN;
    if (failStatuses.includes(f.status)) {
      failed += f.n;
      recentFailed += f.recentN;
    } else if (warnStatuses.includes(f.status)) warned += f.n;
    if (f.lastAt && (!lastAt || f.lastAt > lastAt)) {
      lastAt = f.lastAt;
      lastLabel = f.lastLabel;
    }
  }

  // Rule 2: nothing has ever been here. `never` is not `idle` and not broken.
  if (total === 0) {
    return {
      id: spec.id,
      health: 'never',
      lastAt: null,
      lastLabel: null,
      total: 0,
      failed: 0,
      detail: 'no rows, ever',
    };
  }

  const windowMs = snap.windowHours * 3600_000;
  const active = lastAt ? Date.now() - new Date(lastAt).getTime() < windowMs : false;

  // Which numbers get to decide the colour depends on what the rows MEAN.
  //
  // For a state source, a failed row is a standing problem -- 2,000 entries
  // still sitting unprocessed are a fault today, however old they are. Failure
  // outranks recency, which is exactly what the May 2026 lapse needed.
  //
  // For an event source, a run that failed months ago is history. Judging it on
  // all-time would mean the board could never show a recovery, and would cry
  // wolf permanently over failures already dealt with.
  const isEvent = meta.kind === 'event';
  const basisTotal = isEvent ? recentTotal : total;
  const basisFailed = isEvent ? recentFailed : failed;

  let health: Health;
  if (isEvent && basisTotal === 0) {
    health = 'idle';
  } else {
    const ratio = basisTotal > 0 ? basisFailed / basisTotal : 0;
    if (ratio >= 0.5) health = 'failed';
    else if (basisFailed > 0) health = 'degraded';
    else if (active) health = 'ok';
    else health = 'idle';
  }

  const parts: string[] = [];
  if (isEvent) {
    parts.push(`${recentTotal} in 14d`);
    if (recentFailed) parts.push(`${recentFailed} failed`);
    parts.push(`${total} all-time`);
    if (failed) parts.push(`${failed} failed all-time`);
  } else {
    parts.push(`${total} total`);
    if (failed) parts.push(`${failed} failed`);
    if (warned) parts.push(`${warned} pending`);
  }
  parts.push(ago(lastAt));

  return { id: spec.id, health, lastAt, lastLabel, total, failed, detail: parts.join(' · ') };
}

export function resolveAll(specs: NodeSpec[], snap: Snapshot): Record<string, NodeState> {
  const out: Record<string, NodeState> = {};
  for (const spec of specs) out[spec.id] = resolveNode(spec, snap);
  return out;
}

export { ago };
