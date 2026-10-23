#!/usr/bin/env node
// DG.7.reader: reads error reports and writes one file per cluster for an agent to act on.
//
//   node pipeline/tools/reports.mjs --since 2026-10-22T00:00:00Z
//   node pipeline/tools/reports.mjs --fixture pipeline/tools/fixtures/diagnostics.request.json [more files]
//
// READ ONLY. Live mode needs RETRO_API_BASE and ADMIN_SECRET in the environment (never in a file, never
// printed, never logged) and makes only two kinds of call, both GET:
//   /admin/diagnostics                          the list
//   /admin/diagnostics/<reference>/download     one report
// PRIVACY. The person's note is never written anywhere: only "has note: yes/no". Everything else that is
// copied out of a report is a closed-list id, a code, a number or a timestamp, and is checked against a
// strict pattern first, so even a surprise field cannot carry words into a file an agent reads.
// No dependencies; Node 20+.
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REFERENCE = /^r-[0-9A-HJKMNP-TV-Z]{4}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SAFE = /^[A-Za-z0-9_./:-]{1,64}$/;
const ISO = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$/;
const STATE_OPEN = '<!-- reports-state';
const STATE_CLOSE = '-->';
const MAX_BREADCRUMBS = 50;
const MAX_HINT_STEPS = 8;
const DEFAULT_OUT = fileURLToPath(new URL('../reports/', import.meta.url));

/** A closed-list id, or "?" if it is anything else (never copy free text). */
export const safe = (v) => (typeof v === 'string' && SAFE.test(v) ? v : '?');
const optSafe = (v) => (v === undefined || v === null ? undefined : safe(v));
const num = (v) => (Number.isFinite(v) && v >= 0 && v <= 1e9 ? Math.trunc(v) : 0);
const iso = (v) => (typeof v === 'string' && ISO.test(v) ? v : null);
const arr = (v) => (Array.isArray(v) ? v : []);

/** Reduces one raw report to the privacy-safe facts the cluster files need. The note becomes a boolean. */
export function digest(raw, id) {
  const r = raw && typeof raw === 'object' ? raw : {};
  const env = r.environment && typeof r.environment === 'object' ? r.environment : {};
  const ob = r.outbox && typeof r.outbox === 'object' ? r.outbox : {};
  const crumbs = [
    ...arr(r.events).map((e) => ({
      t: iso(e?.t), kind: safe(e?.kind), screen: optSafe(e?.screen), control: optSafe(e?.control), sheet: optSafe(e?.sheet),
    })),
    ...arr(r.network).map((n) => ({
      t: iso(n?.t), kind: 'request', method: optSafe(n?.method), route: optSafe(n?.route),
      status: Number.isFinite(n?.status) ? num(n.status) : undefined, code: optSafe(n?.code),
    })),
  ].filter((c) => c.t).sort((a, b) => (a.t < b.t ? -1 : a.t > b.t ? 1 : 0));
  const failures = arr(r.failures).map((f) => ({ t: iso(f?.t), code: safe(f?.code), screen: optSafe(f?.screen) })).filter((f) => f.t);
  const crashes = arr(r.crashes).map((c) => ({ t: iso(c?.t), kind: safe(c?.kind) })).filter((c) => c.t);
  const lastFailure = failures.reduce((a, f) => (!a || f.t >= a.t ? f : a), null);
  const lastCrash = crashes.reduce((a, c) => (!a || c.t >= a.t ? c : a), null);
  const originScreen = [...crumbs].reverse().find((c) => c.screen)?.screen;
  let code = 'none';
  let screen = originScreen ?? 'none';
  if (lastCrash && (!lastFailure || lastCrash.t > lastFailure.t)) {
    code = 'crash';
  } else if (lastFailure) {
    code = lastFailure.code;
    screen = lastFailure.screen ?? originScreen ?? 'none';
  }
  const version = typeof env.appVersion === 'string' && SAFE.test(env.appVersion) ? env.appVersion : 'unknown';
  const build = typeof env.build === 'string' && SAFE.test(env.build) ? env.build : 'unknown';
  return {
    id: UUID.test(String(id)) || REFERENCE.test(String(id)) ? String(id) : 'unknown',
    createdAt: iso(r.createdAt) ?? '1970-01-01T00:00:00.000Z',
    key: `${code}/${screen}/${version}(${build})`,
    code, screen, version, build,
    hasNote: typeof r.note === 'string' && r.note.trim() !== '',
    offline: env.network === 'none',
    outbox: { queued: num(ob.queued), sending: num(ob.sending), sent: num(ob.sent), failed: num(ob.failed) },
    breadcrumbs: crumbs.slice(-MAX_BREADCRUMBS),
  };
}

const crumbText = (c) => {
  const parts = [c.t, c.kind];
  if (c.screen) parts.push(`screen=${c.screen}`);
  if (c.control) parts.push(`control=${c.control}`);
  if (c.sheet) parts.push(`sheet=${c.sheet}`);
  if (c.route) parts.push(`${c.method ?? '?'} ${c.route}`);
  if (c.status !== undefined) parts.push(`status=${c.status}`);
  if (c.code) parts.push(`code=${c.code}`);
  return parts.join(' ');
};

/** "journal -> offline -> POST /v2/entries 0 -> report.send", from the newest report's last breadcrumbs. */
export function reproductionHint(d) {
  const steps = [];
  let offlineAdded = false;
  for (const c of d.breadcrumbs) {
    let step;
    if (c.kind === 'request') {
      if (d.offline && !offlineAdded) { steps.push('offline'); offlineAdded = true; }
      step = `${c.method ?? '?'} ${c.route ?? '?'} ${c.status ?? '?'}`;
    } else if (c.kind === 'screen_shown') step = c.screen;
    else if (c.kind === 'control_tapped') step = c.control;
    else if (c.kind === 'sheet_opened') step = `sheet:${c.sheet ?? '?'}`;
    if (step && steps[steps.length - 1] !== step) steps.push(step);
  }
  const tail = steps.slice(-MAX_HINT_STEPS);
  if (d.code !== 'none') tail.push(`=> ${d.code}`);
  return tail.length ? tail.join(' -> ') : 'no breadcrumbs in this report';
}

export function fileNameFor(key) {
  return `${key.split('/').join('--').replace(/[^A-Za-z0-9._-]/g, '-')}.md`;
}

const range = (a, b) => (a === b ? a : `${a} to ${b}`);

export function renderCluster(key, entries) {
  const sorted = [...entries].sort((a, b) => (a.createdAt < b.createdAt ? -1 : a.createdAt > b.createdAt ? 1 : a.id < b.id ? -1 : 1));
  const newest = sorted[sorted.length - 1];
  const builds = [...new Set(sorted.map((e) => `${e.version}(${e.build})`))];
  const sum = (f) => sorted.reduce((n, e) => n + e.outbox[f], 0);
  const noteYes = sorted.filter((e) => e.hasNote).length;
  const lines = [
    `# Cluster ${key}`,
    '',
    `- Count: ${sorted.length}`,
    `- First seen: ${sorted[0].createdAt}`,
    `- Last seen: ${newest.createdAt}`,
    `- Builds: ${builds.join(', ')}`,
    `- Reports with a note: ${noteYes} of ${sorted.length} (the note itself is never copied)`,
    `- Outbox counts, summed: queued ${sum('queued')}, sending ${sum('sending')}, sent ${sum('sent')}, failed ${sum('failed')}`,
    '',
    '## Reproduction hint',
    '',
    reproductionHint(newest),
    '',
    '## References',
    '',
    ...sorted.map((e) => `- ${e.id} (${e.createdAt}, has note: ${e.hasNote ? 'yes' : 'no'})`),
    '',
    `## Last ${MAX_BREADCRUMBS} breadcrumbs of the newest report (${newest.id})`,
    '',
    ...(newest.breadcrumbs.length ? newest.breadcrumbs.map((c) => `- ${crumbText(c)}`) : ['- none']),
    '',
    STATE_OPEN,
    JSON.stringify(sorted),
    STATE_CLOSE,
    '',
  ];
  return lines.join('\n');
}

function loadState(text) {
  const i = text.indexOf(`${STATE_OPEN}\n`);
  if (i < 0) return [];
  const j = text.indexOf(`\n${STATE_CLOSE}`, i);
  if (j < 0) return [];
  try {
    const parsed = JSON.parse(text.slice(i + STATE_OPEN.length + 1, j));
    // Re-check what a file on disk claims: only keep rows that still look like digests.
    return arr(parsed).filter((e) => e && typeof e.id === 'string' && typeof e.key === 'string' && e.outbox && Array.isArray(e.breadcrumbs));
  } catch {
    return [];
  }
}

/** Merges digests into the cluster files in outDir. Re-running never duplicates a reference. */
export async function writeClusters(digests, outDir) {
  await mkdir(outDir, { recursive: true });
  const byKey = new Map();
  for (const d of digests) byKey.set(d.key, [...(byKey.get(d.key) ?? []), d]);
  let added = 0;
  for (const [key, fresh] of byKey) {
    const file = join(outDir, fileNameFor(key));
    let existing = [];
    try { existing = loadState(await readFile(file, 'utf8')); } catch { /* first time */ }
    const merged = new Map(existing.map((e) => [e.id, e]));
    for (const d of fresh) { if (!merged.has(d.id)) added += 1; merged.set(d.id, d); }
    await writeFile(file, renderCluster(key, [...merged.values()]));
  }
  return { clusters: byKey.size, added };
}

function parseArgs(argv) {
  const args = { since: null, fixtures: [], out: DEFAULT_OUT };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--since') args.since = argv[++i];
    else if (a === '--out') args.out = argv[++i];
    else if (a === '--fixture') { while (argv[i + 1] && !argv[i + 1].startsWith('--')) args.fixtures.push(argv[++i]); }
    else throw new Error(`unknown argument ${safe(a)}`);
  }
  return args;
}

async function readLive(env, since, fetchImpl) {
  const base = env.RETRO_API_BASE;
  const secret = env.ADMIN_SECRET;
  if (!base || !secret) throw new Error('set RETRO_API_BASE and ADMIN_SECRET in the environment');
  if (!/^https?:\/\//.test(base)) throw new Error('RETRO_API_BASE must start with http:// or https://');
  const root = base.replace(/\/+$/, '');
  const get = async (path) => {
    let res;
    try { res = await fetchImpl(`${root}${path}`, { method: 'GET', headers: { 'x-admin-secret': secret } }); } catch { throw new Error('the viewer could not be reached'); }
    if (!res.ok) throw new Error(`the viewer answered ${num(res.status)}`);
    return res.json();
  };
  const list = await get('/admin/diagnostics?limit=500');
  const rows = arr(list?.data).filter((r) => REFERENCE.test(String(r?.reference)) && (!since || String(r?.createdAt) >= since));
  const out = [];
  for (const row of rows) out.push(digest(await get(`/admin/diagnostics/${row.reference}/download`), row.reference));
  return out;
}

export async function main({ argv, env, fetchImpl = globalThis.fetch, log = console.log, fail = console.error }) {
  try {
    const args = parseArgs(argv);
    if (args.since !== null && !ISO.test(args.since)) throw new Error('--since must be an ISO time ending in Z, like 2026-10-22T00:00:00Z');
    let digests;
    if (args.fixtures.length) {
      digests = [];
      for (const f of args.fixtures) {
        const raw = JSON.parse(await readFile(f, 'utf8'));
        const d = digest(raw, raw?.reportId);
        if (!args.since || d.createdAt >= args.since) digests.push(d);
      }
    } else {
      if (!args.since) throw new Error('give --since <iso> (or --fixture <file>)');
      digests = await readLive(env, args.since, fetchImpl);
    }
    const { clusters, added } = await writeClusters(digests, args.out);
    log(`read ${digests.length} reports, ${added} new, ${clusters} clusters written`);
    return 0;
  } catch (err) {
    fail(`reports: ${err instanceof Error && !(err instanceof SyntaxError) ? err.message : 'could not read the input'}`);
    return 1;
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  process.exitCode = await main({ argv: process.argv.slice(2), env: process.env });
}
