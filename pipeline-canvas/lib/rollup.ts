import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import type { RollupFact, Snapshot, SourceMeta } from './types';

// ---------------------------------------------------------------------------
// One declarative entry per source. Adding a source is one entry here; adding a
// *node* that reads it is a pure manifest edit with no query at all.
//
// `select` lists the ONLY columns we ever pull. No content, script, excerpt or
// embedding column appears anywhere in this file, and none may be added: this
// dashboard aggregates over 27 people's journals and must never carry their
// words to a browser.
// ---------------------------------------------------------------------------

type Rec = Record<string, unknown>;

/** Matches what createClient() actually returns, which is not SupabaseClient's default. */
type Db = SupabaseClient<any, 'public', 'public', any, any>;

type SourceDef = {
  source: string;
  kind: 'state' | 'event';
  table: string;
  select: string;
  ts: string;
  bucket: (r: Rec) => string;
  status: (r: Rec) => string;
  label?: (r: Rec) => string | null;
};

const s = (v: unknown, fallback = 'unknown') =>
  typeof v === 'string' && v.length > 0 ? v : fallback;

const err = (v: unknown) => (v ? String(v).slice(0, 140) : null);

export const SOURCES: SourceDef[] = [
  {
    source: 'raw_content',
    kind: 'state',
    table: 'raw_content',
    select: 'id,content_type,processing_status,created_at,processing_error',
    ts: 'created_at',
    bucket: (r) => s(r.content_type),
    status: (r) => s(r.processing_status, 'pending'),
    label: (r) => err(r.processing_error),
  },
  {
    source: 'pipeline_run_traces',
    kind: 'event',
    table: 'pipeline_run_traces',
    select: 'id,kind,status,started_at,duration_ms,error_message',
    ts: 'started_at',
    bucket: (r) => s(r.kind),
    status: (r) => s(r.status, 'running'),
    label: (r) => err(r.error_message),
  },
  {
    source: 'assertions',
    kind: 'state',
    table: 'assertions',
    select: 'id,predicate,status,created_at,valid_to,retirement_reason',
    ts: 'created_at',
    bucket: (r) => s(r.predicate),
    // An assertion with valid_to set has been superseded, whatever status says.
    status: (r) => (r.valid_to ? 'retired' : s(r.status, 'active')),
    label: (r) => err(r.retirement_reason),
  },
  {
    source: 'behavior_patterns',
    kind: 'state',
    table: 'behavior_patterns',
    select: 'id,slug,status,created_at,instance_count,retirement_reason',
    ts: 'created_at',
    bucket: (r) => s(r.status, 'candidate'),
    status: (r) => s(r.status, 'candidate'),
    label: (r) => (r.slug ? String(r.slug) : null),
  },
  {
    source: 'assertion_evidence',
    kind: 'state',
    table: 'assertion_evidence',
    select: 'id,evidence_role,created_at',
    ts: 'created_at',
    bucket: (r) => s(r.evidence_role, 'evidence'),
    status: () => 'written',
  },
  {
    source: 'entities',
    kind: 'state',
    table: 'entities',
    select: 'id,entity_type,status,created_at',
    ts: 'created_at',
    bucket: (r) => s(r.entity_type),
    status: (r) => s(r.status, 'active'),
  },
  {
    source: 'entity_resolution_candidates',
    kind: 'state',
    table: 'entity_resolution_candidates',
    select: 'id,status,created_at',
    ts: 'created_at',
    bucket: () => 'all',
    status: (r) => s(r.status, 'pending'),
  },
  {
    source: 'user_understanding',
    kind: 'state',
    table: 'user_understanding',
    select: 'id,version,created_at,model',
    ts: 'created_at',
    bucket: () => 'all',
    status: () => 'written',
    label: (r) => (r.version != null ? `v${r.version}` : null),
  },
  {
    source: 'observations',
    kind: 'state',
    table: 'observations',
    select: 'id,created_at',
    ts: 'created_at',
    bucket: () => 'all',
    status: () => 'written',
  },
  {
    source: 'insights',
    kind: 'state',
    table: 'insights',
    select: 'id,created_at',
    ts: 'created_at',
    bucket: () => 'all',
    status: () => 'written',
  },
  {
    source: 'podcast_episodes',
    kind: 'state',
    table: 'podcast_episodes',
    select: 'id,status,generation_type,created_at,audio_url,error_message',
    ts: 'created_at',
    bucket: (r) => s(r.generation_type, 'all'),
    status: (r) => s(r.status, 'pending'),
    label: (r) => err(r.error_message),
  },
  {
    source: 'lint_findings',
    kind: 'state',
    table: 'lint_findings',
    select: 'id,check_id,created_at',
    ts: 'created_at',
    bucket: (r) => s(r.check_id, 'all'),
    status: () => 'open',
  },
  {
    source: 'remediation_log',
    kind: 'state',
    table: 'remediation_log',
    select: 'id,capability,created_at',
    ts: 'created_at',
    bucket: (r) => s(r.capability, 'all'),
    status: () => 'logged',
  },
  {
    source: 'integration_connections',
    kind: 'state',
    table: 'integration_connections',
    select: 'id,provider_id,status,created_at',
    ts: 'created_at',
    bucket: (r) => s(r.provider_id),
    status: (r) => s(r.status, 'pending'),
  },
  {
    source: 'integration_jobs',
    kind: 'state',
    table: 'integration_jobs',
    select: 'id,job_type,status,created_at',
    ts: 'created_at',
    bucket: (r) => s(r.job_type, 'all'),
    status: (r) => s(r.status, 'queued'),
  },
  {
    source: 'integration_sync_runs',
    kind: 'event',
    table: 'integration_sync_runs',
    select: 'id,run_type,status,started_at',
    ts: 'started_at',
    bucket: (r) => s(r.run_type, 'all'),
    status: (r) => s(r.status, 'running'),
  },
  {
    source: 'integration_test_runs',
    kind: 'event',
    table: 'integration_test_runs',
    select: 'id,test_suite,status,started_at,error_message',
    ts: 'started_at',
    bucket: (r) => s(r.test_suite, 'all'),
    status: (r) => s(r.status, 'running'),
    label: (r) => err(r.error_message),
  },
  {
    source: 'source_payloads',
    kind: 'state',
    table: 'source_payloads',
    select: 'id,provider_object_type,captured_at',
    ts: 'captured_at',
    bucket: (r) => s(r.provider_object_type, 'all'),
    status: () => 'stored',
  },
  {
    source: 'source_items',
    kind: 'state',
    table: 'source_items',
    select: 'id,created_at',
    ts: 'created_at',
    bucket: () => 'all',
    status: () => 'stored',
  },
  {
    source: 'analysis_units',
    kind: 'state',
    table: 'analysis_units',
    select: 'id,created_at',
    ts: 'created_at',
    bucket: () => 'all',
    status: () => 'stored',
  },
];

const PAGE = 1000;
const MAX_ROWS = 20000;
const SEP = '||';

/** How far back an `event` source looks when judging whether it is healthy. */
const RECENT_DAYS = 14;

async function fetchSource(
  db: Db,
  def: SourceDef,
): Promise<{ facts: RollupFact[]; meta: SourceMeta }> {
  const recentCutoff = new Date(Date.now() - RECENT_DAYS * 86400_000).toISOString();
  const acc = new Map<string, RollupFact>();
  let total = 0;
  let truncated = false;

  for (let from = 0; from < MAX_ROWS; from += PAGE) {
    const { data, error } = await db
      .from(def.table)
      .select(def.select)
      .order(def.ts, { ascending: false })
      .range(from, from + PAGE - 1);

    if (error) {
      // A failed read must not look like an empty table. Propagate it so every
      // node on this source resolves to `unknown` rather than green or grey.
      return {
        facts: [],
        meta: { kind: def.kind, total: 0, truncated: false, error: error.message },
      };
    }

    const rows = (data ?? []) as unknown as Rec[];
    for (const r of rows) {
      total += 1;
      const bucket = def.bucket(r);
      const status = def.status(r);
      const k = bucket + SEP + status;
      let f = acc.get(k);
      if (!f) {
        f = { source: def.source, bucket, status, n: 0, recentN: 0, lastAt: null, lastLabel: null };
        acc.set(k, f);
      }
      f.n += 1;
      const ts = r[def.ts] ? String(r[def.ts]) : null;
      if (ts && ts >= recentCutoff) f.recentN += 1;
      if (ts && (!f.lastAt || ts > f.lastAt)) {
        f.lastAt = ts;
        f.lastLabel = def.label ? def.label(r) : null;
      }
    }

    if (rows.length < PAGE) break;
    if (from + PAGE >= MAX_ROWS) truncated = true;
  }

  return {
    facts: [...acc.values()],
    meta: { kind: def.kind, total, truncated, error: null },
  };
}

export async function buildSnapshot(windowHours = 24): Promise<Snapshot> {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_KEY;
  if (!url || !key) throw new Error('SUPABASE_URL / SUPABASE_SERVICE_KEY are not set');

  const db = createClient(url, key, { auth: { persistSession: false } });

  const results = await Promise.all(
    SOURCES.map(async (def) => [def.source, await fetchSource(db, def)] as const),
  );

  const facts: RollupFact[] = [];
  const sources: Record<string, SourceMeta> = {};
  for (const [name, r] of results) {
    facts.push(...r.facts);
    sources[name] = r.meta;
  }

  return { takenAt: new Date().toISOString(), windowHours, facts, sources };
}
