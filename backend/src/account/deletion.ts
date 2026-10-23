import { DoorError } from '../doors/errors.js';
import type { AppleDeletionTools } from '../services/apple-tokens.js';
import type { AppleResult, DeletionNote, DeletionRow, DeletionStore, StepResult } from './store.js';

/**
 * Account deletion (BE0.7 + BE6.6a + BE6.6b; contract 06 §8; App Review 5.1.1(v)).
 *
 * The request (`request`, called by the door):
 *   1. a deletion already under way answers its own id, calling no one;
 *   2. with APPLE_REVOKE_ENABLED on: a fresh Apple code is exchanged right
 *      here (it lives ~5 minutes and works once) and its token sealed; a code
 *      for another Apple account or a refused code is `invalid_credentials`,
 *      Apple down is `upstream_unavailable`, and no code with no stored token
 *      is `apple_confirmation_required`. In all three NOTHING is locked;
 *   3. the lock (one transaction, migration 028): the deletion row, access
 *      suspended, token_version bumped, every refresh family ended. Only then
 *      does the door answer 202, and the finish starts in the background.
 *
 * The finish (`run`, after the 202 and from the sweeper after a crash or a
 * redeploy; one worker per row through a lease):
 *   Apple revoke -> brain sweep -> diagnostics -> DELETE users row (cascades)
 *   -> brain sweep again (files written mid-way) -> deleted.
 * An external step that keeps failing is retried a few times in a run and
 * over MAX_RUNS runs with backoff, then recorded as `failed` and the deletion
 * goes on: the users-row delete is never gated on Apple or the brain. A
 * failing users-row delete is retried for as long as it takes, with an alert
 * each time.
 *
 * Never logged or stored in the log: an Apple code, a token, a ciphertext, an
 * email, a name, an Apple subject. The log line (below) has a closed shape.
 */

/** A run past this many claims records a failing external step as failed and goes on. */
export const MAX_RUNS = 5;
/** How long a worker holds a row; longer than the slowest run (two sweeps x three tries x the brain timeout). */
export const LEASE_SECONDS = 30 * 60;
/** Tries per external step inside one run. */
export const TRIES_PER_RUN = 3;
/** The waits between tries inside one run. */
export const APPLE_RETRY_MS = [1_000, 4_000];
export const BRAIN_RETRY_MS = [2_000, 10_000];
/** A big library is thousands of storage calls (qa-be06). */
export const BRAIN_SWEEP_TIMEOUT_MS = 120_000;
/** The sweeper's tick and how many rows it takes per tick. */
export const SWEEP_EVERY_MS = 5 * 60 * 1000;
export const SWEEP_BATCH = 5;

/** The wait before the next run: 2, 4, 8, 16 ... minutes, at most an hour. */
export function backoffMs(runs: number): number {
  return Math.min(60, 2 ** Math.max(1, runs)) * 60_000;
}

// ---------------------------------------------------------------------------
// The brain sweep: POST {AGENT}/users/<id>/delete (Retrospect-agent#142).

export type BrainSweepResult =
  | { kind: 'ok'; grantsFailed: number; objectsSkipped: number }
  /** A 500 with a report, a 500 'delete failed', a 5xx, a timeout, a network error: call again. */
  | { kind: 'retry'; grantsFailed: number; objectsSkipped: number }
  /** A 400: we sent something wrong. Not retried. */
  | { kind: 'bug' }
  /** A 401/403, a 500 "server misconfigured", a 404 (route not deployed): a config error. Alerted, retried. */
  | { kind: 'misconfigured' };

export interface BrainSweep {
  sweep(userId: string): Promise<BrainSweepResult>;
}

type SweepFetch = (url: string, init: {
  method: 'POST'; headers: Record<string, string>; body: string; signal?: AbortSignal;
}) => Promise<{ status: number; text(): Promise<string> }>;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const count = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) && v >= 0 ? Math.floor(v) : 0);

/** The real sweep, over the internal secret. The brain's answer is read for its counts only. */
export function createBrainSweep(cfg: {
  baseUrl: string; internalSecret: string; fetch?: SweepFetch; timeoutMs?: number;
}): BrainSweep {
  const doFetch: SweepFetch = cfg.fetch ?? ((url, init) => fetch(url, init));
  const base = cfg.baseUrl.replace(/\/+$/, '');
  return {
    async sweep(userId) {
      if (!UUID.test(userId)) return { kind: 'bug' };
      let status: number;
      let body: Record<string, unknown> | null = null;
      try {
        const res = await doFetch(`${base}/users/${encodeURIComponent(userId.toLowerCase())}/delete`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'X-Internal-Secret': cfg.internalSecret },
          body: JSON.stringify({ confirm: 'delete' }),
          signal: AbortSignal.timeout(cfg.timeoutMs ?? BRAIN_SWEEP_TIMEOUT_MS),
        });
        status = res.status;
        const text = await res.text();
        try {
          const parsed: unknown = text ? JSON.parse(text) : null;
          body = parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed as Record<string, unknown> : null;
        } catch {
          body = null;
        }
      } catch {
        return { kind: 'retry', grantsFailed: 0, objectsSkipped: 0 };
      }
      const counts = { grantsFailed: count(body?.grantsFailed), objectsSkipped: count(body?.objectsSkipped) };
      if (status === 200 && body?.ok === true) return { kind: 'ok', ...counts };
      if (status === 400) return { kind: 'bug' };
      if (status === 401 || status === 403 || status === 404) return { kind: 'misconfigured' };
      // The brain's own config error, told apart by the start of its fixed error word, never logged.
      if (status === 500 && typeof body?.error === 'string' && body.error.startsWith('server misconfigured')) return { kind: 'misconfigured' };
      return { kind: 'retry', ...counts };
    },
  };
}

// ---------------------------------------------------------------------------
// The log: one line per step, a closed shape, ids are the deletion's only.

export const DELETION_STEPS = ['request', 'apple', 'sweep_before', 'diagnostics', 'user_row', 'sweep_after', 'run'] as const;
export const DELETION_RESULTS = [
  'locked', 'already_locked', 'revoked', 'already_revoked', 'no_token', 'skipped', 'ok', 'failed', 'retry', 'deferred', 'deleted',
] as const;
export interface DeletionLogLine {
  deletionId: string;
  step: (typeof DELETION_STEPS)[number];
  result: (typeof DELETION_RESULTS)[number];
  run?: number;
  grantsFailed?: number;
  objectsSkipped?: number;
  removed?: number;
}

/** Builds the line as written: anything outside the closed shape is dropped or written "invalid". */
export function deletionLogLine(entry: DeletionLogLine): Record<string, string | number> {
  const line: Record<string, string | number> = {
    job: 'account.delete',
    deletionId: typeof entry.deletionId === 'string' && UUID.test(entry.deletionId) ? entry.deletionId : 'invalid',
    step: (DELETION_STEPS as readonly string[]).includes(entry.step) ? entry.step : 'invalid',
    result: (DELETION_RESULTS as readonly string[]).includes(entry.result) ? entry.result : 'invalid',
  };
  for (const k of ['run', 'grantsFailed', 'objectsSkipped', 'removed'] as const) {
    if (entry[k] !== undefined) line[k] = count(entry[k]);
  }
  return line;
}

const stdoutLog = (entry: DeletionLogLine) => {
  try {
    process.stdout.write(`${JSON.stringify(deletionLogLine(entry))}\n`);
  } catch {
    // A log line must never break a deletion.
  }
};

// ---------------------------------------------------------------------------
// The service.

export interface AccountDeletionDeps {
  store: DeletionStore;
  /** Undefined while APPLE_REVOKE_ENABLED is off: then nothing calls Apple and nothing answers 409. */
  apple?: AppleDeletionTools;
  brain: BrainSweep;
  diagnostics: { deleteFor(userId: string): Promise<number> };
  now: () => number;
  sleep?: (ms: number) => Promise<void>;
  /** Alerts (Sentry in production). Errors passed here carry no personal value. */
  report: (err: unknown, where: string) => void;
  log?: (line: DeletionLogLine) => void;
  /** How the finish is started after the 202; setImmediate by default, tests may run it inline. */
  schedule?: (run: () => void) => void;
}

export interface AccountDeletion {
  /** The door's call: answers the deletion id once the account is locked; throws a DoorError otherwise. */
  request(input: { userId: string; appleAuthorizationCode?: string }): Promise<{ id: string }>;
  /** Starts the finish of one deletion in the background (no-op if another worker holds it). */
  start(id: string): void;
  /** Claims and runs one deletion now; resolves when this run stops. */
  runNow(id: string): Promise<'finished' | 'deferred' | 'busy'>;
  /** The sweeper's tick: claims due rows and runs them one by one; resolves to how many it ran. */
  sweep(): Promise<number>;
}

type StepOutcome<T> = { done: T } | { retry: true; partial?: T };

export function createAccountDeletion(deps: AccountDeletionDeps): AccountDeletion {
  const { store, apple, brain } = deps;
  const sleep = deps.sleep ?? ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));
  const log = deps.log ?? stdoutLog;
  const schedule = deps.schedule ?? ((run: () => void) => { setImmediate(run); });
  const iso = (ms: number) => new Date(ms).toISOString();
  const alert = (what: string, where: string) => {
    try {
      deps.report(new Error(`account deletion: ${what}`), where);
    } catch {
      // Nowhere left to report to.
    }
  };

  async function request(input: { userId: string; appleAuthorizationCode?: string }): Promise<{ id: string }> {
    const prep = await store.prepare(input.userId);
    if (prep.outcome === 'no_user') throw new DoorError('unauthenticated');
    if (prep.deletionId) {
      log({ deletionId: prep.deletionId, step: 'request', result: 'already_locked' });
      start(prep.deletionId);
      return { id: prep.deletionId };
    }

    let sealed: string | null = null;
    if (apple) {
      if (input.appleAuthorizationCode !== undefined) {
        if (!prep.appleUserId) throw new DoorError('invalid_credentials');
        const exchanged = await apple.exchange(input.appleAuthorizationCode, prep.appleUserId);
        if (exchanged.outcome === 'unavailable') throw new DoorError('upstream_unavailable');
        if (exchanged.outcome !== 'ok') throw new DoorError('invalid_credentials');
        sealed = apple.seal(exchanged.refreshToken);
      } else if (!prep.hasAppleToken) {
        throw new DoorError('apple_confirmation_required');
      }
    }

    const locked = await store.lock(input.userId, iso(deps.now()), apple !== undefined, sealed);
    if (locked.outcome === 'apple_confirmation_required') throw new DoorError('apple_confirmation_required');
    if (locked.outcome === 'no_user') throw new DoorError('unauthenticated');
    log({ deletionId: locked.id, step: 'request', result: locked.created ? 'locked' : 'already_locked' });
    if (locked.created && !apple) log({ deletionId: locked.id, step: 'apple', result: 'skipped' });
    start(locked.id);
    return { id: locked.id };
  }

  async function appleStep(row: DeletionRow): Promise<StepOutcome<AppleResult>> {
    if (!apple) return { done: 'skipped' };
    const sealedToken = await store.appleToken(row.id);
    if (!sealedToken) return { done: 'no_token' };
    let token: string;
    try {
      token = apple.open(sealedToken);
    } catch {
      // A wrong TOKEN_ENCRYPTION_KEY or a damaged value: no retry can open it.
      alert('the stored Apple token cannot be opened', 'account.delete.apple');
      return { done: 'failed' };
    }
    for (let attempt = 0; attempt < TRIES_PER_RUN; attempt++) {
      const result = await apple.revoke(token);
      if (result === 'revoked' || result === 'already_revoked') return { done: result };
      if (result === 'refused') {
        // invalid_client and friends: our configuration, so alert; a later run may succeed once it's fixed.
        alert('Apple refused the revoke', 'account.delete.apple');
        return { retry: true };
      }
      if (attempt < TRIES_PER_RUN - 1) await sleep(APPLE_RETRY_MS[attempt] ?? 4_000);
    }
    return { retry: true };
  }

  async function sweepStep(row: DeletionRow, where: 'sweep_before' | 'sweep_after'): Promise<StepOutcome<{ result: StepResult; grantsFailed: number; objectsSkipped: number }>> {
    let last = { grantsFailed: 0, objectsSkipped: 0 };
    for (let attempt = 0; attempt < TRIES_PER_RUN; attempt++) {
      const r = await brain.sweep(row.userId);
      if (r.kind === 'ok') return { done: { result: 'ok', grantsFailed: r.grantsFailed, objectsSkipped: r.objectsSkipped } };
      if (r.kind === 'bug') {
        alert('the brain refused the sweep request (400)', `account.delete.${where}`);
        return { done: { result: 'failed', ...last } };
      }
      if (r.kind === 'misconfigured') {
        alert('the brain sweep is misconfigured', `account.delete.${where}`);
        return { retry: true, partial: { result: 'failed', ...last } };
      }
      last = { grantsFailed: r.grantsFailed, objectsSkipped: r.objectsSkipped };
      if (attempt < TRIES_PER_RUN - 1) await sleep(BRAIN_RETRY_MS[attempt] ?? 10_000);
    }
    return { retry: true, partial: { result: 'failed', ...last } };
  }

  /** Runs a claimed row as far as it can go this time. */
  async function run(claimed: DeletionRow): Promise<'finished' | 'deferred'> {
    const row = { ...claimed };
    const finalRun = row.runs >= MAX_RUNS;
    const step = (s: DeletionLogLine['step'], result: DeletionLogLine['result'], extra: Partial<DeletionLogLine> = {}) =>
      log({ deletionId: row.id, step: s, result, run: row.runs, ...extra });
    const note = async (n: DeletionNote) => {
      await store.note(row.id, n);
      Object.assign(row, n);
    };
    const defer = async () => {
      await store.defer(row.id, iso(deps.now() + backoffMs(row.runs)));
      step('run', 'deferred');
      return 'deferred' as const;
    };

    if (row.state === 'requested') {
      if (row.apple === null) {
        const a = await appleStep(row);
        if ('retry' in a && !finalRun) {
          step('apple', 'retry');
          return defer();
        }
        const apple: AppleResult = 'done' in a ? a.done : 'failed';
        await note({ apple });
        step('apple', apple);
      }

      if (row.sweepBefore === null) {
        const s = await sweepStep(row, 'sweep_before');
        if ('retry' in s && !finalRun) {
          step('sweep_before', 'retry');
          return defer();
        }
        const done = 'done' in s ? s.done : s.partial ?? { result: 'failed' as const, grantsFailed: 0, objectsSkipped: 0 };
        await note({ sweepBefore: done.result, grantsFailed: done.grantsFailed, objectsSkipped: done.objectsSkipped });
        step('sweep_before', done.result, { grantsFailed: done.grantsFailed, objectsSkipped: done.objectsSkipped });
      }

      if (row.diagnostics === null) {
        try {
          const removed = await deps.diagnostics.deleteFor(row.userId);
          await note({ diagnostics: 'ok', diagnosticsRemoved: removed });
          step('diagnostics', 'ok', { removed });
        } catch {
          alert('diagnostics deleteFor failed', 'account.delete.diagnostics');
          if (!finalRun) {
            step('diagnostics', 'retry');
            return defer();
          }
          // The rows cascade with the users row; only stored report files could be left.
          await note({ diagnostics: 'failed' });
          step('diagnostics', 'failed');
        }
      }

      // The users row goes whatever Apple and the brain said. Its own failure is retried, never given up on.
      let after: Awaited<ReturnType<DeletionStore['deleteUser']>>;
      try {
        after = await store.deleteUser(row.id, iso(deps.now()));
      } catch {
        alert('the users row delete failed', 'account.delete.user_row');
        step('user_row', 'retry');
        return defer();
      }
      if (after !== 'user_deleted' && after !== 'deleted') {
        alert('the users row delete found no open deletion', 'account.delete.user_row');
        step('user_row', 'failed');
        return defer();
      }
      row.state = 'user_deleted';
      step('user_row', 'deleted');
    }

    if (row.state === 'user_deleted') {
      if (row.sweepAfter === null) {
        const s = await sweepStep(row, 'sweep_after');
        if ('retry' in s && !finalRun) {
          step('sweep_after', 'retry');
          return defer();
        }
        const done = 'done' in s ? s.done : s.partial ?? { result: 'failed' as const, grantsFailed: 0, objectsSkipped: 0 };
        await note({ sweepAfter: done.result, objectsSkipped: row.objectsSkipped + done.objectsSkipped });
        step('sweep_after', done.result, { objectsSkipped: done.objectsSkipped });
      }
      await store.finish(row.id, iso(deps.now()));
      step('run', 'deleted');
    }
    return 'finished';
  }

  async function runSafely(row: DeletionRow): Promise<'finished' | 'deferred'> {
    try {
      return await run(row);
    } catch {
      // A store call failed mid-run: let go of the lease so the sweeper tries again later.
      alert('a deletion run failed', 'account.delete.run');
      try {
        await store.defer(row.id, iso(deps.now() + backoffMs(row.runs)));
      } catch {
        // The lease runs out on its own; the sweeper picks the row up then.
      }
      return 'deferred';
    }
  }

  async function runNow(id: string): Promise<'finished' | 'deferred' | 'busy'> {
    const row = await store.claim(id, iso(deps.now()), LEASE_SECONDS);
    if (!row) return 'busy';
    return runSafely(row);
  }

  function start(id: string): void {
    schedule(() => {
      runNow(id).catch(() => alert('a deletion could not be started', 'account.delete.run'));
    });
  }

  async function sweep(): Promise<number> {
    const rows = await store.claimDue(iso(deps.now()), LEASE_SECONDS, SWEEP_BATCH);
    for (const row of rows) await runSafely(row);
    return rows.length;
  }

  return { request, start, runNow, sweep };
}

/**
 * The resumable sweeper, started by server.ts like the diagnostics purge: once
 * at start (a redeploy or crash left rows half done), then every five
 * minutes. One tick at a time. Returns a stop function.
 */
export function startDeletionSweeper(
  deletion: Pick<AccountDeletion, 'sweep'>,
  opts: { report: (err: unknown) => void; every?: (run: () => void, ms: number) => () => void },
): () => void {
  let running = false;
  const tick = () => {
    if (running) return;
    running = true;
    deletion.sweep().then(
      () => { running = false; },
      (err: unknown) => {
        running = false;
        opts.report(err);
      },
    );
  };
  const every = opts.every ?? ((fn, ms) => {
    const t = setInterval(fn, ms);
    t.unref();
    return () => clearInterval(t);
  });
  tick();
  return every(tick, SWEEP_EVERY_MS);
}
