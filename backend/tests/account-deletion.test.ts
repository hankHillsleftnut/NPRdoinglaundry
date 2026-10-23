/**
 * BE0.7: DELETE /v2/account over HTTP (the real app, a database built from
 * every migration on PGlite, the real auth middleware reading it), and the
 * background steps on fakes: a fake Apple (an injected fetch, a throwaway key)
 * and a fake brain. Nothing reaches Apple or the brain; no real person.
 */
import assert from 'node:assert/strict';
import { generateKeyPairSync, randomBytes } from 'node:crypto';
import test, { before } from 'node:test';
import {
  BRAIN_SWEEP_TIMEOUT_MS, LEASE_SECONDS, MAX_RUNS, createAccountDeletion, createBrainSweep, deletionLogLine, startDeletionSweeper,
  type AccountDeletion, type BrainSweep, type BrainSweepResult, type DeletionLogLine,
} from '../src/account/deletion.js';
import { supabaseDeletionStore, type DeletionStore } from '../src/account/store.js';
import { userLookupWith, type UserRowsClient } from '../src/middleware/auth.js';
import { supabaseSessionStore, startSession } from '../src/sessions/store.js';
import { issueAccessToken } from '../src/sessions/tokens.js';
import {
  APPLE_REVOKE_URL, APPLE_TOKEN_URL, createAppleDeletionTools, type AppleFetch, type AppleTokenSettings,
} from '../src/services/apple-tokens.js';
import { freshDatabase, insertUser, type PGlite } from './support/database.js';
import { startHarness, type Harness } from './support/harness.js';
import { pgliteRpc } from './support/pglite-rpc.js';

const SECRET = process.env.JWT_SECRET ?? '';
const NOW = 1_800_000_000_000;
const CODE = 'c0de.fake.delete-0001';
const APPLE_REFRESH = 'r.apple-refresh-from-code';
const STORED_REFRESH = 'r.apple-refresh-stored';

let db: PGlite;
before(async () => {
  db = await freshDatabase();
});

// ---------------------------------------------------------------------------
// Fakes.

const pair = generateKeyPairSync('ec', { namedCurve: 'P-256' });
const SEALING = randomBytes(32).toString('base64');
const appleSettings = (over: Partial<AppleTokenSettings> = {}): AppleTokenSettings => ({
  clientId: 'com.example.test-app', teamId: 'TEAMTEST01', keyId: 'KIDTEST001',
  privateKey: pair.privateKey.export({ type: 'pkcs8', format: 'pem' }).toString(),
  revokeEnabled: true, tokenEncryptionKey: SEALING, ...over,
});
/** Seals as the sign-in keeper would have (same key as every world's tools). */
const sealKept = (token: string) => createAppleDeletionTools({ settings: appleSettings(), fetch: fakeApple().fetch })!.seal(token);
const idTokenFor = (sub: string) =>
  [{ alg: 'none' }, { iss: 'https://appleid.apple.com', sub }].map((p) => Buffer.from(JSON.stringify(p)).toString('base64url')).join('.') + '.sig';

type AppleReply = { status: number; body?: unknown } | Error;
function fakeApple(opts: { token?: (fields: Record<string, string>) => AppleReply; revoke?: (fields: Record<string, string>) => AppleReply } = {}) {
  const calls: { url: string; fields: Record<string, string> }[] = [];
  const fetch: AppleFetch = async (url, init) => {
    const fields = Object.fromEntries(new URLSearchParams(init.body));
    calls.push({ url, fields });
    const r = url === APPLE_TOKEN_URL ? (opts.token?.(fields) ?? { status: 500 }) : (opts.revoke?.(fields) ?? { status: 200, body: {} });
    if (r instanceof Error) throw r;
    return { ok: r.status >= 200 && r.status < 300, status: r.status, json: async () => r.body };
  };
  return { fetch, calls, revokes: () => calls.filter((c) => c.url === APPLE_REVOKE_URL) };
}

/** The brain: each call answers from the script (last entry repeats) and records whether the users row still existed. */
function fakeBrain(script: BrainSweepResult[] = [{ kind: 'ok', grantsFailed: 0, objectsSkipped: 0 }]) {
  const calls: { userId: string; userRowExisted: boolean }[] = [];
  const brain: BrainSweep = {
    async sweep(userId) {
      const { rows } = await db.query<{ n: number }>('SELECT count(*)::int n FROM users WHERE id = $1', [userId]);
      calls.push({ userId, userRowExisted: rows[0]!.n === 1 });
      return script[Math.min(calls.length - 1, script.length - 1)]!;
    },
  };
  return { brain, calls };
}

interface World {
  h: Harness;
  deletion: AccountDeletion;
  store: DeletionStore;
  apple: ReturnType<typeof fakeApple>;
  brain: ReturnType<typeof fakeBrain>;
  diagnosticsCalls: string[];
  scheduled: (() => void)[];
  lines: string[];
  alerts: string[];
  clock: { now: number };
  close(): Promise<void>;
}

async function world(opts: {
  appleOn?: boolean; apple?: ReturnType<typeof fakeApple>; brain?: ReturnType<typeof fakeBrain>; store?: DeletionStore;
} = {}): Promise<World> {
  const store = opts.store ?? supabaseDeletionStore(pgliteRpc(db));
  const apple = opts.apple ?? fakeApple();
  const brain = opts.brain ?? fakeBrain();
  const clock = { now: NOW };
  const scheduled: (() => void)[] = [];
  const lines: string[] = [];
  const alerts: string[] = [];
  const diagnosticsCalls: string[] = [];
  const tools = opts.appleOn ? createAppleDeletionTools({ settings: appleSettings(), fetch: apple.fetch, now: () => clock.now }) : undefined;
  const deletion = createAccountDeletion({
    store,
    ...(tools ? { apple: tools } : {}),
    brain: brain.brain,
    diagnostics: { deleteFor: async (id) => { diagnosticsCalls.push(id); return 2; } },
    now: () => clock.now,
    sleep: async () => undefined,
    report: (err, where) => alerts.push(`${where}: ${(err as Error).message}`),
    log: (l: DeletionLogLine) => lines.push(JSON.stringify(deletionLogLine(l))),
    // The background run is held here, so a test sees the state right at the 202 and runs the rest itself.
    schedule: (run) => { scheduled.push(run); },
  });
  const h = await startHarness({
    now: NOW,
    account: deletion,
    userLookup: userLookupWith(pgliteRpc(db) as unknown as UserRowsClient),
    sessions: supabaseSessionStore(pgliteRpc(db)),
  });
  return { h, deletion, store, apple, brain, diagnosticsCalls, scheduled, lines, alerts, clock, close: () => h.close() };
}

async function person(access = 'member', storedToken: string | null = null, sealWith?: (t: string) => string) {
  const sub = `apple-del-${randomBytes(6).toString('hex')}`;
  const id = await insertUser(db, sub);
  await db.query('UPDATE users SET access = $2 WHERE id = $1', [id, access]);
  if (storedToken && sealWith) await db.query('UPDATE users SET apple_refresh_token_ciphertext = $2 WHERE id = $1', [id, sealWith(storedToken)]);
  const version = (await db.query<{ v: number }>('SELECT token_version v FROM users WHERE id = $1', [id])).rows[0]!.v;
  const token = issueAccessToken({ userId: id, tokenVersion: version }, SECRET, NOW).token;
  return { id, sub, token, auth: { Authorization: `Bearer ${token}` } };
}

const del = (w: World, auth: Record<string, string>, body: unknown = { confirm: 'delete' }) => w.h.request('DELETE', '/v2/account', body, auth);
const code = (res: { body: unknown }) => ((res.body as { error?: { code?: string } }).error ?? {}).code;
async function row(userId: string) {
  const { rows } = await db.query<Record<string, unknown>>('SELECT * FROM account_deletions WHERE user_id = $1', [userId]);
  return rows[0] ?? null;
}
async function userRow(id: string) {
  const { rows } = await db.query<{ access: string; token_version: number }>('SELECT access, token_version FROM users WHERE id = $1', [id]);
  return rows[0] ?? null;
}
async function finish(w: World, id: string) {
  // Runs until finished, moving the clock past each backoff, as the sweeper would.
  for (let i = 0; i < MAX_RUNS + 3; i++) {
    const r = await w.deletion.runNow(id);
    if (r === 'finished') return i + 1;
    w.clock.now += 2 * 60 * 60 * 1000;
  }
  throw new Error('never finished');
}

// ---------------------------------------------------------------------------
// The request.

test('202 comes after the lock: the old access token is dead at once and the refresh is ended', async () => {
  const w = await world();
  try {
    const alice = await person();
    const session = await startSession(supabaseSessionStore(pgliteRpc(db)), { userId: alice.id, tokenVersion: 0 }, SECRET, NOW);
    assert.equal((await w.h.request('GET', '/v2/ping', undefined, alice.auth)).status, 200);

    const res = await del(w, alice.auth);
    assert.equal(res.status, 202);
    const data = (res.body as { data: { deletion: { id: string; state: string } } }).data;
    assert.equal(data.deletion.state, 'deleting');
    // At the moment of the 202, before any background step ran:
    assert.equal(w.scheduled.length, 1, 'the finish is started after the answer');
    assert.deepEqual(await userRow(alice.id), { access: 'suspended', token_version: 1 });
    assert.equal((await row(alice.id))!.id, data.deletion.id);
    assert.equal((await row(alice.id))!.state, 'requested');

    const after = await w.h.request('GET', '/v2/ping', undefined, alice.auth);
    assert.equal(after.status, 401, 'the old access token 401s');
    const refresh = await w.h.request('POST', '/v2/auth/refresh', { refreshToken: session.refreshToken });
    assert.equal(refresh.status, 401, 'and the refresh is refused');
  } finally {
    await w.close();
  }
});

test('a second request, and two at once, get the same deletion', async () => {
  const w = await world();
  try {
    const alice = await person();
    // An old-shape token has no version, so it still reaches the door after the lock.
    const legacy = { Authorization: `Bearer ${w.h.asUser(alice.id)}` };
    const [a, b] = await Promise.all([del(w, alice.auth), del(w, legacy)]);
    const ids = [a, b].filter((r) => r.status === 202).map((r) => (r.body as { data: { deletion: { id: string } } }).data.deletion.id);
    assert.ok(ids.length >= 1);
    for (const r of [a, b]) assert.ok(r.status === 202 || (r.status === 401 && code(r) === 'unauthenticated'), `202 or a dead token, got ${r.status}`);
    const again = await del(w, legacy);
    assert.equal(again.status, 202);
    const againId = (again.body as { data: { deletion: { id: string } } }).data.deletion.id;
    for (const id of ids) assert.equal(id, againId, 'one deletion id');
    assert.equal((await db.query<{ n: number }>('SELECT count(*)::int n FROM account_deletions WHERE user_id = $1', [alice.id])).rows[0]!.n, 1);
    assert.equal((await userRow(alice.id))!.token_version, 1, 'locked once');
  } finally {
    await w.close();
  }
});

test('a waitlisted person and a staff-paused person can both delete; other doors still refuse them', async () => {
  const w = await world();
  try {
    for (const [access, refused] of [['waitlisted', 'invite_required'], ['suspended', 'suspended']] as const) {
      const p = await person(access);
      const ping = await w.h.request('GET', '/v2/ping', undefined, p.auth);
      assert.equal(code(ping), refused, `${access}: other doors still refuse`);
      const res = await del(w, p.auth);
      assert.equal(res.status, 202, `${access} can delete`);
    }
  } finally {
    await w.close();
  }
});

test('the DELETE body reaches the strict schema: a bad or unknown field locks nothing', async () => {
  const w = await world();
  try {
    const alice = await person();
    for (const body of [{ confirm: 'delete', userId: '9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c03' }, { confirm: 'yes' }, {}, { confirm: 'delete', appleAuthorizationCode: '' }]) {
      const res = await del(w, alice.auth, body);
      assert.equal(res.status, 400, JSON.stringify(Object.keys(body)));
      assert.equal(code(res), 'invalid_request');
    }
    assert.equal(await row(alice.id), null);
    assert.equal((await userRow(alice.id))!.token_version, 0);
  } finally {
    await w.close();
  }
});

test('Apple on, no token kept, no code: 409 apple_confirmation_required and nothing locked', async () => {
  const w = await world({ appleOn: true });
  try {
    const alice = await person();
    const res = await del(w, alice.auth);
    assert.equal(res.status, 409);
    assert.deepEqual(res.body, { success: false, error: { code: 'apple_confirmation_required', message: 'Confirm with Apple to finish deleting your account.' } });
    assert.equal(await row(alice.id), null);
    assert.equal((await userRow(alice.id))!.access, 'member');
    assert.equal((await w.h.request('GET', '/v2/ping', undefined, alice.auth)).status, 200, 'still signed in');
    assert.equal(w.apple.calls.length, 0, 'no code: Apple is not called');
  } finally {
    await w.close();
  }
});

test('a fresh code: a different Apple account, a refused code or Apple down lock nothing', async () => {
  const cases: [string, (f: Record<string, string>) => AppleReply, number, string][] = [
    ['another Apple account', () => ({ status: 200, body: { refresh_token: APPLE_REFRESH, id_token: idTokenFor('someone-else') } }), 401, 'invalid_credentials'],
    ['a used or expired code', () => ({ status: 400, body: { error: 'invalid_grant' } }), 401, 'invalid_credentials'],
    ['Apple down', () => ({ status: 503 }), 502, 'upstream_unavailable'],
    ['the network', () => new TypeError('fetch failed'), 502, 'upstream_unavailable'],
  ];
  for (const [what, reply, status, errorCode] of cases) {
    const apple = fakeApple({ token: reply });
    const w = await world({ appleOn: true, apple });
    try {
      const alice = await person();
      const res = await del(w, alice.auth, { confirm: 'delete', appleAuthorizationCode: CODE });
      assert.equal(res.status, status, what);
      assert.equal(code(res), errorCode, what);
      assert.equal(await row(alice.id), null, `${what}: no deletion row`);
      assert.equal((await userRow(alice.id))!.token_version, 0, `${what}: not locked`);
      assert.equal(apple.calls[0]!.fields.code, CODE, 'the code went to Apple');
    } finally {
      await w.close();
    }
  }
});

test('a fresh code is exchanged in the request, sealed with the lock, and its token revoked in the background', async () => {
  const apple = fakeApple({ token: () => ({ status: 200, body: { refresh_token: APPLE_REFRESH, id_token: idTokenFor(subOf.current) } }) });
  const w = await world({ appleOn: true, apple });
  try {
    const alice = await person();
    subOf.current = alice.sub;
    const res = await del(w, alice.auth, { confirm: 'delete', appleAuthorizationCode: CODE });
    assert.equal(res.status, 202);
    const stored = (await db.query<{ c: string }>('SELECT apple_refresh_token_ciphertext c FROM users WHERE id = $1', [alice.id])).rows[0]!.c;
    assert.match(stored, /^v1:/, 'sealed on the users row with the lock');
    assert.equal(stored.includes(APPLE_REFRESH), false);
    const id = String((await row(alice.id))!.id);
    await finish(w, id);
    assert.deepEqual(apple.revokes().map((c) => [c.fields.token, c.fields.token_type_hint]), [[APPLE_REFRESH, 'refresh_token']]);
    assert.equal((await row(alice.id))!.apple, 'revoked');
  } finally {
    await w.close();
  }
});
const subOf = { current: '' };

// ---------------------------------------------------------------------------
// The finish.

test('the full order: Apple, sweep, diagnostics, the users row, sweep again, deleted; the log row outlives the user', async () => {
  const apple = fakeApple();
  const brain = fakeBrain([{ kind: 'ok', grantsFailed: 1, objectsSkipped: 2 }, { kind: 'ok', grantsFailed: 0, objectsSkipped: 1 }]);
  const w = await world({ appleOn: true, apple, brain });
  try {
    // A token kept at sign-in (BE0.5): no code is needed.
    const alice = await person('member', STORED_REFRESH, sealKept);
    const bob = await person('member', 'r.bob-kept', sealKept);
    const res = await del(w, alice.auth);
    assert.equal(res.status, 202);
    assert.equal(apple.calls.length, 0, 'nothing reaches Apple inside the request');
    const id = String((await row(alice.id))!.id);
    assert.equal(await finish(w, id), 1, 'one run');
    assert.deepEqual(apple.revokes().map((c) => c.fields.token), [STORED_REFRESH], 'her kept token, opened and revoked');
    assert.deepEqual(brain.calls.map((c) => [c.userId, c.userRowExisted]), [[alice.id, true], [alice.id, false]], 'swept before and after the users row went');
    assert.deepEqual(w.diagnosticsCalls, [alice.id]);
    assert.equal(await userRow(alice.id), null, 'her users row is gone');
    assert.ok(await userRow(bob.id), 'Bob is untouched');
    assert.equal(await row(bob.id), null, 'and has no deletion');
    const log = await row(alice.id);
    assert.equal(log!.state, 'deleted');
    assert.equal(log!.apple, 'revoked');
    assert.equal(log!.sweep_before, 'ok');
    assert.equal(log!.sweep_after, 'ok');
    assert.equal(log!.grants_failed, 1);
    assert.equal(log!.objects_skipped, 3);
    assert.equal(log!.diagnostics_removed, 2);
    const steps = w.lines.map((l) => { const j = JSON.parse(l) as { step: string; result: string }; return `${j.step}:${j.result}`; });
    assert.deepEqual(steps, ['request:locked', 'apple:revoked', 'sweep_before:ok', 'diagnostics:ok', 'user_row:deleted', 'sweep_after:ok', 'run:deleted']);
    assert.equal(await w.deletion.runNow(id), 'busy', 'a finished deletion is not run again');
  } finally {
    await w.close();
  }
});

test("Apple's invalid_grant on revoke means already revoked; the deletion goes on", async () => {
  const apple = fakeApple({
    token: () => ({ status: 200, body: { refresh_token: STORED_REFRESH, id_token: idTokenFor(subOf.current) } }),
    revoke: () => ({ status: 400, body: { error: 'invalid_grant' } }),
  });
  const w = await world({ appleOn: true, apple });
  try {
    const alice = await person();
    subOf.current = alice.sub;
    await del(w, alice.auth, { confirm: 'delete', appleAuthorizationCode: CODE });
    await finish(w, String((await row(alice.id))!.id));
    assert.equal(apple.revokes().length, 1, 'not retried');
    assert.equal((await row(alice.id))!.apple, 'already_revoked');
    assert.equal((await row(alice.id))!.state, 'deleted');
  } finally {
    await w.close();
  }
});

test('Apple 5xx on revoke is retried, then the next run revokes and carries on', async () => {
  let fail = 4;
  const apple = fakeApple({
    token: () => ({ status: 200, body: { refresh_token: STORED_REFRESH, id_token: idTokenFor(subOf.current) } }),
    revoke: () => (fail-- > 0 ? { status: 503 } : { status: 200, body: {} }),
  });
  const w = await world({ appleOn: true, apple });
  try {
    const alice = await person();
    subOf.current = alice.sub;
    await del(w, alice.auth, { confirm: 'delete', appleAuthorizationCode: CODE });
    const id = String((await row(alice.id))!.id);
    assert.equal(await w.deletion.runNow(id), 'deferred', 'three tries this run, then later');
    assert.equal(apple.revokes().length, 3);
    assert.ok(await userRow(alice.id), 'nothing deleted yet');
    assert.equal(await w.deletion.runNow(id), 'busy', 'not due yet');
    w.clock.now += 60 * 60 * 1000;
    assert.equal(await w.deletion.runNow(id), 'finished');
    assert.equal((await row(alice.id))!.apple, 'revoked');
  } finally {
    await w.close();
  }
});

test('Apple failing every run: after the last run it is recorded failed and the account is deleted anyway', async () => {
  const apple = fakeApple({
    token: () => ({ status: 200, body: { refresh_token: STORED_REFRESH, id_token: idTokenFor(subOf.current) } }),
    revoke: () => ({ status: 500 }),
  });
  const w = await world({ appleOn: true, apple });
  try {
    const alice = await person();
    subOf.current = alice.sub;
    await del(w, alice.auth, { confirm: 'delete', appleAuthorizationCode: CODE });
    const runs = await finish(w, String((await row(alice.id))!.id));
    assert.equal(runs, MAX_RUNS);
    assert.equal((await row(alice.id))!.apple, 'failed');
    assert.equal(await userRow(alice.id), null, 'the users row went anyway');
  } finally {
    await w.close();
  }
});

test('a kept token that cannot be opened (a changed key) is alerted, recorded failed, and the deletion goes on', async () => {
  const apple = fakeApple();
  const w = await world({ appleOn: true, apple });
  try {
    const otherKey = (t: string) => createAppleDeletionTools({
      settings: appleSettings({ tokenEncryptionKey: randomBytes(32).toString('base64') }), fetch: apple.fetch,
    })!.seal(t);
    const alice = await person('member', STORED_REFRESH, otherKey);
    assert.equal((await del(w, alice.auth)).status, 202, 'a token is kept, so no 409');
    assert.equal(await finish(w, String((await row(alice.id))!.id)), 1);
    assert.equal(apple.calls.length, 0, 'nothing sent to Apple');
    assert.equal((await row(alice.id))!.apple, 'failed');
    assert.ok(w.alerts.some((a) => a.includes('cannot be opened')));
    assert.equal(await userRow(alice.id), null);
  } finally {
    await w.close();
  }
});

test('flag off: nothing calls Apple, no 409, Apple is skipped and the account is deleted', async () => {
  const apple = fakeApple();
  const w = await world({ appleOn: false, apple });
  try {
    const alice = await person();
    const res = await del(w, alice.auth, { confirm: 'delete', appleAuthorizationCode: CODE });
    assert.equal(res.status, 202, 'no 409 with the flag off, even with no token');
    await finish(w, String((await row(alice.id))!.id));
    assert.equal(apple.calls.length, 0, 'Apple never called');
    assert.equal((await row(alice.id))!.apple, 'skipped');
    assert.ok(w.lines.some((l) => l.includes('"step":"apple","result":"skipped"')), 'logged apple:skipped');
    assert.equal(await userRow(alice.id), null);
  } finally {
    await w.close();
  }
});

test('a brain sweep failing every time never blocks the users-row delete, and is called again after it', async () => {
  const script: { reply: BrainSweepResult } = { reply: { kind: 'retry', grantsFailed: 2, objectsSkipped: 0 } };
  const calls: { userId: string; userRowExisted: boolean }[] = [];
  const brain = {
    calls,
    brain: {
      async sweep(userId: string) {
        const { rows } = await db.query<{ n: number }>('SELECT count(*)::int n FROM users WHERE id = $1', [userId]);
        calls.push({ userId, userRowExisted: rows[0]!.n === 1 });
        return script.reply;
      },
    } satisfies BrainSweep,
  };
  const w = await world({ brain });
  try {
    const alice = await person();
    await del(w, alice.auth);
    const id = String((await row(alice.id))!.id);
    // Many runs, hours apart: the users row goes after MAX_RUNS, the deletion stays open.
    for (let i = 0; i < MAX_RUNS + 10; i++) {
      assert.equal(await w.deletion.runNow(id), 'deferred', `run ${i + 1} is not finished while files may remain`);
      w.clock.now += 7 * 60 * 60 * 1000;
    }
    assert.equal(await userRow(alice.id), null, 'the users row went anyway');
    let log = await row(alice.id);
    assert.equal(log!.state, 'user_deleted', 'never marked deleted while the second sweep has not succeeded');
    assert.equal(log!.sweep_before, 'failed');
    assert.equal(log!.sweep_after, 'failed', 'the record says what is still to do');
    assert.equal(log!.grants_failed, 2, 'what the brain could not revoke is recorded');

    // The brain is deployed or fixed: a later sweeper run (a new server) finishes it from the record.
    script.reply = { kind: 'ok', grantsFailed: 0, objectsSkipped: 1 };
    const restarted = createAccountDeletion({
      store: supabaseDeletionStore(pgliteRpc(db)), brain: brain.brain,
      diagnostics: { deleteFor: async () => 0 }, now: () => w.clock.now, sleep: async () => undefined, report: () => undefined, log: () => undefined,
    });
    assert.equal(await restarted.runNow(id), 'finished');
    log = await row(alice.id);
    assert.equal(log!.state, 'deleted');
    assert.equal(log!.sweep_after, 'ok');
    assert.ok(brain.calls.some((c) => !c.userRowExisted), 'swept again after the users row went');
    const lastBefore = brain.calls.map((c) => c.userRowExisted).lastIndexOf(true);
    const firstAfter = brain.calls.findIndex((c) => !c.userRowExisted);
    assert.ok(firstAfter > lastBefore, 'the second sweep comes after the row delete');
  } finally {
    await w.close();
  }
});

test('a brain 400 is our bug: alerted, not retried, and the deletion goes on', async () => {
  const brain = fakeBrain([{ kind: 'bug' }, { kind: 'ok', grantsFailed: 0, objectsSkipped: 0 }]);
  const w = await world({ brain });
  try {
    const alice = await person();
    await del(w, alice.auth);
    assert.equal(await finish(w, String((await row(alice.id))!.id)), 1);
    assert.equal(brain.calls.length, 2, 'one call before (not retried), one after');
    assert.equal((await row(alice.id))!.sweep_before, 'failed');
    assert.ok(w.alerts.some((a) => a.startsWith('account.delete.sweep_before')));
  } finally {
    await w.close();
  }
});

test('killed after the lock: a new server\'s sweeper finishes it; killed mid-run: after the lease runs out', async () => {
  const w = await world();
  try {
    const alice = await person();
    const bob = await person();
    await del(w, alice.auth);
    await del(w, bob.auth);
    // The process dies: nothing scheduled ever runs. Bob's run had even claimed his row.
    const bobId = String((await row(bob.id))!.id);
    assert.ok(await w.store.claim(bobId, new Date(w.clock.now).toISOString(), LEASE_SECONDS));

    const restarted = createAccountDeletion({
      store: supabaseDeletionStore(pgliteRpc(db)), brain: fakeBrain().brain,
      diagnostics: { deleteFor: async () => 0 }, now: () => w.clock.now, sleep: async () => undefined, report: () => undefined, log: () => undefined,
    });
    // Ticks until nothing is due (rows other tests left open are swept too; batches are SWEEP_BATCH).
    const drain = async () => { let n = 0; while (n < 50 && (await restarted.sweep()) > 0) n++; };
    await drain();
    assert.equal(await userRow(alice.id), null, 'Alice finished by the sweeper');
    assert.ok(await userRow(bob.id), "Bob's row is still held by the dead worker's lease");

    w.clock.now += (LEASE_SECONDS + 1) * 1000;
    await drain();
    assert.equal(await userRow(bob.id), null, 'finished once the lease ran out');
    assert.equal((await row(bob.id))!.state, 'deleted');
  } finally {
    await w.close();
  }
});

test('a failing users-row delete is retried and alerted, never marked done', async () => {
  const real = supabaseDeletionStore(pgliteRpc(db));
  let failures = 2;
  const store: DeletionStore = { ...real, deleteUser: async (id, at) => { if (failures-- > 0) throw new Error('delete_account_user failed (57014)'); return real.deleteUser(id, at); } };
  const w = await world({ store });
  try {
    const alice = await person();
    await del(w, alice.auth);
    const id = String((await row(alice.id))!.id);
    assert.equal(await w.deletion.runNow(id), 'deferred');
    assert.equal((await row(alice.id))!.state, 'requested');
    assert.ok(w.alerts.some((a) => a.startsWith('account.delete.user_row')));
    await finish(w, id);
    assert.equal(await userRow(alice.id), null);
    assert.equal((await row(alice.id))!.state, 'deleted');
  } finally {
    await w.close();
  }
});

test('no code, token or ciphertext in any log line, answer, alert or the deletion row', async () => {
  const apple = fakeApple({
    token: () => ({ status: 200, body: { refresh_token: APPLE_REFRESH, id_token: idTokenFor(subOf.current) } }),
    revoke: () => ({ status: 400, body: { error: 'invalid_client', echo: APPLE_REFRESH } }),
  });
  const w = await world({ appleOn: true, apple });
  try {
    const alice = await person();
    subOf.current = alice.sub;
    const res = await del(w, alice.auth, { confirm: 'delete', appleAuthorizationCode: CODE });
    const cipher = (await db.query<{ c: string }>('SELECT apple_refresh_token_ciphertext c FROM users WHERE id = $1', [alice.id])).rows[0]!.c;
    await finish(w, String((await row(alice.id))!.id));
    const everything = [JSON.stringify(res.body), ...w.h.logLines, ...w.lines, ...w.alerts, JSON.stringify(await row(alice.id))].join('\n');
    for (const secret of [CODE, APPLE_REFRESH, cipher, alice.sub]) {
      assert.equal(everything.includes(secret), false, 'a secret leaked');
    }
    assert.ok(w.alerts.some((a) => a.includes('Apple refused the revoke')), 'invalid_client is alerted');
  } finally {
    await w.close();
  }
});

test('the sweeper runs once at start and then on its tick, one tick at a time', async () => {
  let runs = 0;
  let release: () => void = () => undefined;
  const ticks: (() => void)[] = [];
  const stop = startDeletionSweeper({
    sweep: () => { runs++; return new Promise<number>((r) => { release = () => r(0); }); },
  }, { report: () => undefined, every: (fn) => { ticks.push(fn); return () => undefined; } });
  assert.equal(runs, 1, 'at start');
  ticks[0]!();
  assert.equal(runs, 1, 'no second run while the first is going');
  release();
  await new Promise((r) => setImmediate(r));
  ticks[0]!();
  assert.equal(runs, 2);
  stop();
});

// ---------------------------------------------------------------------------
// The brain client.

test('the brain sweep: the request, and how each answer is read', async () => {
  const sent: { url: string; headers: Record<string, string>; body: string; timeout: boolean }[] = [];
  const reply = { status: 200, body: '' };
  const sweep = createBrainSweep({
    baseUrl: 'http://agent.test/', internalSecret: 'test-only-not-a-key',
    fetch: async (url, init) => {
      sent.push({ url, headers: init.headers, body: init.body, timeout: init.signal !== undefined });
      if (reply.status === 0) throw new Error('network');
      return { status: reply.status, text: async () => reply.body };
    },
  });
  const ID = '9A8B7C6D-5E4F-4A3B-8C2D-1E0F9A8B7C03';
  const answer = async (status: number, body: unknown) => {
    reply.status = status;
    reply.body = typeof body === 'string' ? body : JSON.stringify(body);
    return sweep.sweep(ID);
  };
  assert.deepEqual(await answer(200, { ok: true, grantsFailed: 0, objectsSkipped: 3 }), { kind: 'ok', grantsFailed: 0, objectsSkipped: 3 });
  assert.equal(sent[0]!.url, 'http://agent.test/users/9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c03/delete', 'lower case, as Postgres prints it');
  assert.equal(sent[0]!.headers['X-Internal-Secret'], 'test-only-not-a-key');
  assert.deepEqual(JSON.parse(sent[0]!.body), { confirm: 'delete' });
  assert.ok(sent[0]!.timeout);
  assert.ok(BRAIN_SWEEP_TIMEOUT_MS >= 60_000, 'a generous timeout');
  assert.deepEqual(await answer(500, { ok: false, grantsFailed: 2, objectsSkipped: 1, failedSteps: ['x'] }), { kind: 'retry', grantsFailed: 2, objectsSkipped: 1 });
  assert.deepEqual(await answer(500, { error: 'delete failed', ok: false }), { kind: 'retry', grantsFailed: 0, objectsSkipped: 0 });
  assert.deepEqual(await answer(500, { error: 'server misconfigured: missing INTERNAL_API_SECRET' }), { kind: 'misconfigured' });
  assert.deepEqual(await answer(401, { error: 'unauthorized' }), { kind: 'misconfigured' });
  assert.deepEqual(await answer(400, { error: 'invalid userId' }), { kind: 'bug' });
  assert.deepEqual(await answer(200, { ok: false }), { kind: 'retry', grantsFailed: 0, objectsSkipped: 0 }, 'a 200 that is not ok is not done');
  assert.deepEqual(await answer(502, 'not json'), { kind: 'retry', grantsFailed: 0, objectsSkipped: 0 });
  assert.deepEqual(await answer(0, null), { kind: 'retry', grantsFailed: 0, objectsSkipped: 0 }, 'network or timeout');
  const before = sent.length;
  assert.deepEqual(await sweep.sweep('../../etc'), { kind: 'bug' }, 'a non-UUID is never sent');
  assert.equal(sent.length, before);
});
