import { test } from 'node:test';
import assert from 'node:assert/strict';
import { resolveNode } from '../lib/health';
import type { NodeSpec, Snapshot } from '../lib/types';

const now = Date.now();
const iso = (msAgo: number) => new Date(now - msAgo).toISOString();
const HOUR = 3600_000;
const DAY = 24 * HOUR;

const meta = (
  total: number,
  opts: { kind?: 'state' | 'event'; error?: string | null; truncated?: boolean } = {},
) => ({
  kind: opts.kind ?? ('state' as const),
  total,
  truncated: opts.truncated ?? false,
  error: opts.error ?? null,
});

const fact = (
  source: string,
  bucket: string,
  status: string,
  n: number,
  lastAt: string | null,
  lastLabel: string | null = null,
  recentN = 0,
) => ({ source, bucket, status, n, recentN, lastAt, lastLabel });

function snap(partial: Partial<Snapshot> = {}): Snapshot {
  return {
    takenAt: new Date(now).toISOString(),
    windowHours: 24,
    facts: [],
    sources: {},
    ...partial,
  };
}

const node = (probe: NodeSpec['probe']): NodeSpec => ({
  id: 'n',
  title: 'n',
  purpose: 'A test node.',
  region: 'ingest',
  order: 0,
  probe,
});

// ---------------------------------------------------------------------------
// The rule the whole board rests on.
// ---------------------------------------------------------------------------

test('a failed read is unknown, never ok and never notInstrumented', () => {
  const s = snap({ sources: { t: meta(0, { error: 'connection reset' }) } });
  const r = resolveNode(node({ kind: 'rollup', source: 't' }), s);
  assert.equal(r.health, 'unknown');
  assert.notEqual(r.health, 'ok');
  assert.notEqual(r.health, 'notInstrumented');
  assert.match(r.detail, /connection reset/);
});

test('a source missing from the snapshot is unknown, not never', () => {
  const r = resolveNode(node({ kind: 'rollup', source: 'absent' }), snap());
  assert.equal(r.health, 'unknown');
});

test('an empty table is never, which is distinct from idle and from failed', () => {
  const s = snap({ sources: { t: meta(0) } });
  const r = resolveNode(node({ kind: 'rollup', source: 't' }), s);
  assert.equal(r.health, 'never');
  assert.equal(r.detail, 'no rows, ever');
});

test('an uninstrumented node reports its reason and claims no health', () => {
  const r = resolveNode(
    node({ kind: 'notInstrumented', reason: 'nothing records it', wouldNeed: 'a trace row' }),
    snap(),
  );
  assert.equal(r.health, 'notInstrumented');
  assert.equal(r.detail, 'nothing records it');
  assert.equal(r.total, 0);
});

// ---------------------------------------------------------------------------
// Failure outranks recency -- the May 2026 lesson.
// ---------------------------------------------------------------------------

test('old failures still read as failed rather than idle', () => {
  const s = snap({
    sources: { raw: meta(2268) },
    facts: [
      fact('raw', 'text', 'failed', 2034, iso(200 * DAY), 'credit balance too low', 2034),
      fact('raw', 'text', 'completed', 234, iso(200 * DAY), null, 234),
    ],
  });
  const r = resolveNode(node({ kind: 'rollup', source: 'raw' }), s);
  assert.equal(r.health, 'failed');
  assert.equal(r.failed, 2034);
  assert.equal(r.total, 2268);
});

test('a minority of failures is degraded, not ok', () => {
  const s = snap({
    sources: { t: meta(100) },
    facts: [
      fact('t', 'b', 'completed', 95, iso(HOUR), null, 95),
      fact('t', 'b', 'failed', 5, iso(HOUR), 'boom', 5),
    ],
  });
  assert.equal(resolveNode(node({ kind: 'rollup', source: 't' }), s).health, 'degraded');
});

test('clean and recent is ok; clean and stale is idle', () => {
  const mk = (lastAt: string) =>
    snap({
      sources: { t: meta(10) },
      facts: [fact('t', 'b', 'completed', 10, lastAt, null, 10)],
    });
  assert.equal(resolveNode(node({ kind: 'rollup', source: 't' }), mk(iso(HOUR))).health, 'ok');
  assert.equal(resolveNode(node({ kind: 'rollup', source: 't' }), mk(iso(9 * DAY))).health, 'idle');
});

// ---------------------------------------------------------------------------
// Bucket selection
// ---------------------------------------------------------------------------

test('a bucketed probe ignores other buckets in the same source', () => {
  const s = snap({
    sources: { t: meta(30) },
    facts: [
      fact('t', 'wanted', 'completed', 10, iso(HOUR), null, 10),
      fact('t', 'other', 'failed', 20, iso(HOUR), null, 20),
    ],
  });
  const r = resolveNode(node({ kind: 'rollup', source: 't', bucket: 'wanted' }), s);
  assert.equal(r.health, 'ok');
  assert.equal(r.total, 10);
  assert.equal(r.failed, 0);
});

test('a bucket with no rows is never, even when its source has plenty', () => {
  const s = snap({
    sources: { t: meta(500) },
    facts: [fact('t', 'other', 'completed', 500, iso(HOUR), null, 500)],
  });
  assert.equal(resolveNode(node({ kind: 'rollup', source: 't', bucket: 'absent' }), s).health, 'never');
});

test('a multi-bucket probe sums its buckets', () => {
  const s = snap({
    sources: { t: meta(30) },
    facts: [
      fact('t', 'a', 'completed', 10, iso(HOUR), null, 10),
      fact('t', 'b', 'completed', 20, iso(HOUR), null, 20),
      fact('t', 'c', 'completed', 99, iso(HOUR), null, 99),
    ],
  });
  const r = resolveNode(node({ kind: 'rollup', source: 't', bucket: ['a', 'b'] }), s);
  assert.equal(r.total, 30);
});

test('custom failStatuses let a sink count only what it cares about', () => {
  const s = snap({
    sources: { j: meta(10) },
    facts: [
      fact('j', 'all', 'dead_letter', 3, iso(HOUR), null, 3),
      fact('j', 'all', 'completed', 7, iso(HOUR), null, 7),
    ],
  });
  const r = resolveNode(
    node({ kind: 'rollup', source: 'j', okStatuses: [], failStatuses: ['dead_letter'] }),
    s,
  );
  assert.equal(r.failed, 3);
  assert.equal(r.health, 'degraded');
});

test('the newest lastAt across buckets wins, with its own label', () => {
  const s = snap({
    sources: { t: meta(2) },
    facts: [
      fact('t', 'a', 'completed', 1, iso(5 * DAY), 'old', 1),
      fact('t', 'b', 'completed', 1, iso(HOUR), 'new', 1),
    ],
  });
  const r = resolveNode(node({ kind: 'rollup', source: 't' }), s);
  assert.equal(r.lastLabel, 'new');
});

// ---------------------------------------------------------------------------
// State vs event. Getting this wrong makes the board lie in one direction or
// the other, so both directions are pinned here.
// ---------------------------------------------------------------------------

test('a STATE source counts old failures against health -- a backlog is a fault today', () => {
  const s = snap({
    sources: { raw: meta(2268, { kind: 'state' }) },
    // 200 days old, nothing recent
    facts: [
      fact('raw', 'b', 'failed', 2034, iso(200 * DAY), 'billing', 0),
      fact('raw', 'b', 'completed', 234, iso(200 * DAY), null, 0),
    ],
  });
  const r = resolveNode(node({ kind: 'rollup', source: 'raw' }), s);
  assert.equal(r.health, 'failed');
});

test('an EVENT source judges on the recent window, so recovery is visible', () => {
  const s = snap({
    sources: { traces: meta(285, { kind: 'event' }) },
    facts: [
      // 185 historical failures, none recent
      fact('traces', 'ingest', 'failed', 185, iso(120 * DAY), 'old boom', 0),
      // 12 recent runs, all clean
      fact('traces', 'ingest', 'completed', 100, iso(2 * HOUR), null, 12),
    ],
  });
  const r = resolveNode(node({ kind: 'rollup', source: 'traces' }), s);
  assert.equal(r.health, 'ok');
  // ...but the all-time damage is still reported, not hidden
  assert.match(r.detail, /185 failed all-time/);
  assert.match(r.detail, /285 all-time/);
});

test('an EVENT source still goes red when the RECENT runs are failing', () => {
  const s = snap({
    sources: { traces: meta(20, { kind: 'event' }) },
    facts: [
      fact('traces', 'ingest', 'failed', 8, iso(HOUR), 'boom', 8),
      fact('traces', 'ingest', 'completed', 12, iso(HOUR), null, 2),
    ],
  });
  assert.equal(resolveNode(node({ kind: 'rollup', source: 'traces' }), s).health, 'failed');
});

test('an EVENT source with no recent rows is idle, not ok and not failed', () => {
  const s = snap({
    sources: { traces: meta(50, { kind: 'event' }) },
    facts: [fact('traces', 'ingest', 'completed', 50, iso(90 * DAY), null, 0)],
  });
  assert.equal(resolveNode(node({ kind: 'rollup', source: 'traces' }), s).health, 'idle');
});
