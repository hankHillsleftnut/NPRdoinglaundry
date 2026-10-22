/**
 * BE2.0b over HTTP on the real app (harness), with invites on a real Postgres
 * (PGlite, migrations 007 and 021, run as service_role): the check door, the
 * serial, and redeem made idempotent for the redeemer and by Idempotency-Key.
 * Tests marked (*) in docs/team/flows/first-run/backend.md fail when the rule
 * they prove is removed.
 */
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import test, { after, before } from 'node:test';
import { asServiceRole, applyMigration, freshDatabase, insertUser, type PGlite } from './support/database.js';
import { pgliteRpc } from './support/pglite-rpc.js';
import { startHarness, type Harness } from './support/harness.js';
import { supabaseAccessStore, type AccessState, type AccessStore } from '../src/access/store.js';
import { supabaseInviteStore, type InviteStore } from '../src/invites/store.js';
import { hashCode, newCode, sealCode } from '../src/invites/codes.js';
import { CheckResponse, CodeBody, RedeemResponse } from '../src/invites/doors.js';
import { DOOR_LIMITS } from '../src/doors/limits.js';

const KEY = process.env.INVITE_CODE_KEY ?? '';
const FIXTURES = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures');
const fixture = (folder: string, name: string) => JSON.parse(readFileSync(join(FIXTURES, folder, name), 'utf8')) as { data?: unknown };
const T0 = Date.parse('2026-10-22T09:00:00.000Z');
let db: PGlite;
let access: AccessStore;
let invites: InviteStore;

function asService<T extends object>(store: T): T {
  return Object.fromEntries(Object.entries(store).map(([k, fn]) => [k, (...a: unknown[]) => asServiceRole(db, () => (fn as (...x: unknown[]) => Promise<unknown>)(...a))])) as T;
}

before(async () => {
  db = await freshDatabase();
  access = asService(supabaseAccessStore(pgliteRpc(db)));
  invites = asService(supabaseInviteStore(pgliteRpc(db)));
});
after(async () => { await db.close(); });

let seq = 1000;
/** Deterministic codes: a counter, no randomness (a different range from invites.test.ts, which has its own database anyway). */
const nextCode = () => newCode(() => { const b = Buffer.alloc(9); b.writeUInt32BE(++seq, 5); return b; });

async function person(h: Harness, state: AccessState, firstName?: string): Promise<string> {
  const id = await insertUser(db);
  await db.query(`UPDATE users SET access = $2, first_name = $3 WHERE id = $1`, [id, state, firstName ?? null]);
  h.users.set(id, { id, appleUserId: `apple-${id}`, access: state, ...(firstName ? { firstName } : {}) });
  return id;
}

/** An invite with a known code, made at `createdAt` (the face's issuedOn). */
async function invite(opts: { kind?: 'founder' | 'member' | 'review'; owner?: string; expiresAt?: string; revoked?: boolean; createdAt?: string } = {}): Promise<string> {
  const code = nextCode();
  await db.query(
    `INSERT INTO invites (code_hash, code_ciphertext, kind, owner_user_id, expires_at, revoked_at, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7)`,
    [hashCode(code), sealCode(code, KEY), opts.kind ?? 'founder', opts.owner ?? null, opts.expiresAt ?? null,
      opts.revoked ? new Date(T0).toISOString() : null, opts.createdAt ?? '2026-10-19T10:00:00.000Z'],
  );
  return code;
}

/** The next invite made gets this serial. */
const nextSerial = (n: number) => db.query(`SELECT setval('invite_serial_seq', $1, false)`, [n]);

const harness = (now = T0) => startHarness({ access, invites, now });
const as = (h: Harness, id: string, extra: Record<string, string> = {}) => ({ Authorization: `Bearer ${h.asUser(id)}`, ...extra });
const check = (h: Harness, id: string, code: string, extra: Record<string, string> = {}) => h.request('POST', '/v2/invites/check', { code }, as(h, id, extra));
const redeem = (h: Harness, id: string, code: string, extra: Record<string, string> = {}) => h.request('POST', '/v2/invites/redeem', { code }, as(h, id, extra));
const code = (body: unknown) => (body as { error?: { code?: string } }).error?.code;
const data = <T>(body: unknown) => (body as { data: T }).data;
const row = async (c: string) => (await db.query<Record<string, unknown>>(
  `SELECT used_by_user_id, used_at, redeem_key, redeemed_on::text AS redeemed_on, serial::int AS serial, code_ciphertext FROM invites WHERE code_hash = $1`, [hashCode(c)])).rows[0]!;
const memberInvites = async (owner: string) =>
  (await db.query<{ n: number }>(`SELECT count(*)::int n FROM invites WHERE owner_user_id = $1 AND kind = 'member'`, [owner])).rows[0]!.n;

/** Two tears' Idempotency-Keys: UUIDs the app would make at touch-down, obviously made up. */
const TEAR_A = '11111111-2222-4333-8444-555555555555';
const TEAR_B = '66666666-7777-4888-9999-aaaaaaaaaaaa';

test('check answers the contract fixtures exactly: usable, yours, alreadyIn', async () => {
  const h = await harness();
  try {
    const priya = await person(h, 'member', 'priya');
    await nextSerial(412);
    const c = await invite({ kind: 'member', owner: priya });
    const sam = await person(h, 'waitlisted', 'sam');
    const usable = await check(h, sam, c);
    assert.equal(usable.status, 200);
    assert.deepEqual(usable.body, fixture('01', 'invite.check.usable.json'));
    assert.deepEqual(data(await check(h, sam, c).then((r) => r.body)), data(usable.body), 'and again: nothing changed');

    assert.equal((await redeem(h, sam, c)).status, 200);
    h.users.set(sam, { ...h.users.get(sam)!, access: 'approved' });
    assert.deepEqual((await check(h, sam, c)).body, fixture('01', 'invite.check.yours.json'), 'the redeemer, now approved, is told it is theirs');

    for (const state of ['approved', 'member', 'staff'] as const) {
      const p = await person(h, state);
      const live = await invite({ kind: 'member', owner: priya });
      assert.deepEqual((await check(h, p, live)).body, fixture('01', 'invite.check.alreadyin.json'), state);
      assert.equal((await row(live)).used_by_user_id, null, 'nothing spent');
    }
  } finally {
    await h.close();
  }
});

test('check says yours for the redeemer even after they are approved, and used for anyone else (*)', async () => {
  const h = await harness();
  try {
    const c = await invite();
    const [a, b] = [await person(h, 'waitlisted'), await person(h, 'waitlisted')];
    assert.equal((await redeem(h, a, c)).status, 200);
    // The token still says waitlisted (a stale token) or approved (a fresh one): the database decides.
    for (const tokenAccess of ['waitlisted', 'approved'] as const) {
      h.users.set(a, { ...h.users.get(a)!, access: tokenAccess });
      const mine = await check(h, a, c);
      assert.equal(mine.status, 200, tokenAccess);
      assert.equal(data<{ reason: string }>(mine.body).reason, 'yours');
    }
    const theirs = await check(h, b, c);
    assert.equal(theirs.status, 400);
    assert.equal(code(theirs.body), 'invite_used');
    assert.equal(JSON.stringify(theirs.body).includes('serial'), false, 'nothing of the spent invite is shown to someone else');
    const m = await person(h, 'member');
    assert.equal(data<{ reason: string }>((await check(h, m, c)).body).reason, 'alreadyIn', 'a member checking a used code is told they are in, as redeem would say');
  } finally {
    await h.close();
  }
});

test('check never spends an invite or touches a row, and never reads code_ciphertext (*)', async () => {
  const h = await harness();
  try {
    const c = await invite();
    // The sealed code is garbage: a check that opened it would fail here.
    await db.query(`UPDATE invites SET code_ciphertext = 'not-a-sealed-code' WHERE code_hash = $1`, [hashCode(c)]);
    const p = await person(h, 'waitlisted');
    const snapshot = () => db.query<Record<string, unknown>>(`SELECT xmin::text AS tx, * FROM invites ORDER BY serial`).then((r) => r.rows);
    const before = await snapshot();
    for (let i = 0; i < 20; i++) assert.equal(data<{ usable: boolean }>((await check(h, p, c)).body).usable, true, `check ${i + 1}`);
    assert.deepEqual(await snapshot(), before, 'no row changed, not even its transaction id');
    assert.equal((await db.query<{ access: string }>(`SELECT access FROM users WHERE id = $1`, [p])).rows[0]!.access, 'waitlisted');

    const { rows } = await db.query<{ def: string }>(`SELECT pg_get_functiondef('invite_check(uuid, text, timestamptz)'::regprocedure) AS def`);
    assert.equal(rows[0]!.def.includes('code_ciphertext'), false, 'the function never names the sealed code');
    assert.equal(/\bi\.\*|SELECT \*/.test(rows[0]!.def), false, 'and never selects whole rows');

    assert.equal((await redeem(h, p, c)).status, 200, 'redeem never opens the sealed code either');
  } finally {
    await h.close();
  }
});

test('check answers invalid for unknown, malformed and revoked codes, expired for expired ones, and needs no INVITE_CODE_KEY', async () => {
  const { createV2Router } = await import('../src/doors/router.js');
  const h = await startHarness({
    access, invites, now: T0,
    v2Router: (door, deps) => createV2Router(door, { ...deps, invites: { ...deps.invites, codeKey: null } }),
  });
  try {
    const p = await person(h, 'waitlisted');
    assert.equal(code((await check(h, p, nextCode())).body), 'invite_invalid', 'well formed, never issued');
    assert.equal(code((await check(h, p, 'not a code')).body), 'invite_invalid');
    assert.equal(code((await check(h, p, 'U'.repeat(13))).body), 'invite_invalid', 'outside the alphabet');
    assert.equal(code((await check(h, p, await invite({ revoked: true }))).body), 'invite_invalid', 'revoked says no more than unknown');
    assert.equal(code((await check(h, p, await invite({ expiresAt: new Date(T0 - 1000).toISOString() }))).body), 'invite_expired');
    assert.equal(code((await check(h, p, await invite({ expiresAt: new Date(T0).toISOString() }))).body), 'invite_expired', 'expiring now is expired');
    const live = await check(h, p, await invite({ expiresAt: new Date(T0 + 60_000).toISOString() }));
    assert.equal(live.status, 200, 'before its expiry, and without the code key');
    assert.equal(data<{ usable: boolean }>(live.body).usable, true);
    assert.equal((await h.request('POST', '/v2/invites/check', { code: 'x', extra: 1 }, as(h, p))).status, 400);
    assert.equal(code((await h.request('POST', '/v2/invites/check', {}, as(h, p))).body), 'invalid_request');
  } finally {
    await h.close();
  }
});

test('check is rate-limited per user (20) and per address (60) on its own buckets, not redeem\'s', async () => {
  const h = await harness();
  try {
    const perUser = DOOR_LIMITS.buckets.inviteCheck[0]!.max;
    const perAddress = DOOR_LIMITS.buckets.inviteCheckAddress[0]!.max;
    assert.deepEqual([perUser, perAddress], [20, 60], 'the contract\'s numbers');
    const p = await person(h, 'waitlisted');
    for (let i = 0; i < perUser; i++) assert.equal((await check(h, p, nextCode())).status, 400, `check ${i + 1} is counted, not refused`);
    const over = await check(h, p, nextCode());
    assert.equal(over.status, 429);
    assert.ok(((over.body as { error: { retryAfterSeconds?: number } }).error.retryAfterSeconds ?? 0) > 0);
    assert.equal((await redeem(h, p, nextCode())).status, 400, 'checking never ate the tear\'s tries');

    let sent = perUser + 1;
    while (sent < perAddress) {
      const q = await person(h, 'waitlisted');
      for (let i = 0; i < perUser && sent < perAddress; i++, sent++) assert.equal((await check(h, q, nextCode())).status, 400);
    }
    const fresh = await person(h, 'waitlisted');
    assert.equal((await check(h, fresh, nextCode())).status, 429, `the ${perAddress + 1}th check from this address`);
    assert.equal((await redeem(h, fresh, nextCode())).status, 400, 'and redeem from the address is still open');
  } finally {
    await h.close();
  }
});

test('redeeming twice as the same person returns the same serial and redeemedOn, whatever the key (*)', async () => {
  const h = await harness();
  try {
    await nextSerial(7);
    const c = await invite();
    const p = await person(h, 'waitlisted');
    const first = await redeem(h, p, c, { 'Idempotency-Key': TEAR_A, 'X-Time-Zone': 'Pacific/Honolulu' });
    assert.equal(first.status, 200);
    assert.deepEqual(first.body, fixture('00', 'redeem.response.minimal.json'), 'a founder invite: the contract fixture exactly');
    h.clock.now += 24 * 60 * 60 * 1000;
    const again = [
      await redeem(h, p, c, { 'Idempotency-Key': TEAR_A, 'X-Time-Zone': 'Asia/Tokyo' }),
      await redeem(h, p, c, { 'Idempotency-Key': TEAR_B }),
      await redeem(h, p, c),
    ];
    for (const r of again) assert.deepEqual(r.body, first.body, 'the stored answer, a day later and from elsewhere');
    assert.equal(await memberInvites(p), 3);
    assert.equal((await row(c)).redeem_key, TEAR_A, 'the first key stays on the row');
  } finally {
    await h.close();
  }
});

test('a replayed key with the same code is the same 200; the same key with another code is idempotency_mismatch (*)', async () => {
  const h = await harness();
  try {
    const [c1, c3] = [await invite(), await invite()];
    const a = await person(h, 'waitlisted');
    const first = await redeem(h, a, c1, { 'Idempotency-Key': TEAR_A });
    assert.equal(first.status, 200);
    assert.deepEqual((await redeem(h, a, c1, { 'Idempotency-Key': TEAR_A })).body, first.body);
    assert.deepEqual((await redeem(h, a, ` ${c1.toLowerCase()}`, { 'Idempotency-Key': TEAR_A.toUpperCase() })).body, first.body, 'the code and the key compare normalised');
    const clash = await redeem(h, a, c3, { 'Idempotency-Key': TEAR_A });
    assert.equal(clash.status, 409);
    assert.equal(code(clash.body), 'idempotency_mismatch');
    assert.equal((await row(c3)).used_by_user_id, null, 'the other code is untouched');
    assert.equal(await memberInvites(a), 3);
    assert.equal((await redeem(h, a, c3, { 'Idempotency-Key': TEAR_B })).status, 200, 'a new key: the usual answer (already in, nothing spent)');
    assert.equal((await row(c3)).used_by_user_id, null);

    for (const bad of ['not-a-uuid', 'x'.repeat(65), TEAR_A.slice(0, -1)]) {
      const res = await redeem(h, await person(h, 'waitlisted'), c3, { 'Idempotency-Key': bad });
      assert.equal(code(res.body), 'invalid_request', `key ${bad.length} chars`);
    }
    assert.equal((await row(c3)).used_by_user_id, null, 'a bad key spends nothing');
  } finally {
    await h.close();
  }
});

test('another person\'s key is theirs alone (*)', async () => {
  const h = await harness();
  try {
    const [c1, c2] = [await invite(), await invite()];
    const [a, b] = [await person(h, 'waitlisted'), await person(h, 'waitlisted')];
    const mine = await redeem(h, a, c1, { 'Idempotency-Key': TEAR_A });
    assert.equal(mine.status, 200);
    const spent = await redeem(h, b, c1, { 'Idempotency-Key': TEAR_A });
    assert.equal(code(spent.body), 'invite_used', 'B with A\'s key and A\'s code: B\'s own outcome, never A\'s body');
    const own = await redeem(h, b, c2, { 'Idempotency-Key': TEAR_A });
    assert.equal(own.status, 200);
    assert.notEqual(data<{ invite: { serial: number } }>(own.body).invite.serial, data<{ invite: { serial: number } }>(mine.body).invite.serial);
    assert.deepEqual([(await row(c1)).redeem_key, (await row(c2)).redeem_key], [TEAR_A, TEAR_A], 'the same key on two people\'s rows');
    assert.deepEqual((await redeem(h, a, c1, { 'Idempotency-Key': TEAR_A })).body, mine.body, 'A\'s replay is still A\'s');
    assert.deepEqual((await redeem(h, b, c2, { 'Idempotency-Key': TEAR_A })).body, own.body);
    assert.equal(code((await redeem(h, b, c1, { 'Idempotency-Key': TEAR_A })).body), 'idempotency_mismatch', 'B\'s key now names c2, so c1 under it is B\'s own mismatch, never A\'s answer');
  } finally {
    await h.close();
  }
});

test('redeemedOn follows X-Time-Zone, and UTC without it (*)', async () => {
  const h = await harness(Date.parse('2026-10-22T06:30:00.000Z'));
  try {
    const on = async (headers: Record<string, string>) => {
      const res = await redeem(h, await person(h, 'waitlisted'), await invite(), headers);
      assert.equal(res.status, 200);
      return data<{ invite: { redeemedOn: string } }>(res.body).invite.redeemedOn;
    };
    assert.equal(await on({ 'X-Time-Zone': 'America/Los_Angeles' }), '2026-10-21', '23:30 the evening before, where the person is');
    assert.equal(await on({}), '2026-10-22', 'UTC without a header');
    assert.equal(await on({ 'X-Time-Zone': 'Not/A_Zone' }), '2026-10-22', 'UTC with a header that names no zone');
    assert.equal(await on({ 'X-Time-Zone': 'Pacific/Kiritimati' }), '2026-10-22', 'UTC+14: still the 22nd');
  } finally {
    await h.close();
  }
});

test('already_in returns invite null and spends nothing', async () => {
  const h = await harness();
  try {
    const c = await invite();
    const m = await person(h, 'member');
    const res = await redeem(h, m, c, { 'Idempotency-Key': TEAR_A });
    assert.equal(res.status, 200);
    assert.deepEqual(res.body, fixture('00', 'redeem.response.alreadyin.json'));
    assert.deepEqual(await row(c).then((r) => [r.used_by_user_id, r.redeem_key, r.redeemed_on]), [null, null, null]);
    assert.equal(await memberInvites(m), 0);
  } finally {
    await h.close();
  }
});

test('migration 021 numbers existing invites in creation order and keeps serials unique', async () => {
  const old = await freshDatabase({ before: '021_invite_serial.sql' });
  try {
    const made: string[] = [];
    for (const day of ['03', '01', '02']) {
      const c = nextCode();
      made.push(hashCode(c));
      await old.query(`INSERT INTO invites (code_hash, kind, created_at) VALUES ($1, 'founder', $2)`, [hashCode(c), `2026-10-${day}T12:00:00.000Z`]);
    }
    // One was redeemed before the migration: it gets the UTC date of its use.
    const redeemer = await insertUser(old);
    await old.query(`UPDATE invites SET used_by_user_id = $1, used_at = '2026-10-05T23:30:00.000Z' WHERE code_hash = $2`, [redeemer, made[0]]);
    await applyMigration(old, '021_invite_serial.sql');
    const { rows } = await old.query<{ code_hash: string; serial: number; redeemed_on: string | null }>(
      `SELECT code_hash, serial::int AS serial, redeemed_on::text AS redeemed_on FROM invites ORDER BY created_at`);
    assert.deepEqual(rows, [
      { code_hash: made[1], serial: 1, redeemed_on: null }, { code_hash: made[2], serial: 2, redeemed_on: null }, { code_hash: made[0], serial: 3, redeemed_on: '2026-10-05' },
    ]);
    const replay = await old.query<{ r: { outcome: string; serial: number; redeemed_on: string } }>(
      `SELECT redeem_invite($1, $2, now(), '{}', '{}', NULL, current_date) AS r`, [redeemer, made[0]]);
    assert.deepEqual(replay.rows[0]!.r, { outcome: 'redeemed', invited_by: null, serial: 3, redeemed_on: '2026-10-05' }, "a pre-migration redeemer's retry has a date");
    const next = await old.query<{ serial: number }>(`INSERT INTO invites (code_hash, kind) VALUES ($1, 'review') RETURNING serial::int AS serial`, [hashCode(nextCode())]);
    assert.equal(next.rows[0]!.serial, 4, 'the sequence continues after the backfill');
    await assert.rejects(old.query(`INSERT INTO invites (code_hash, kind, serial) VALUES ($1, 'review', 4)`, [hashCode(nextCode())]), (e: { code?: string }) => e.code === '23505');
    const fns = await old.query<{ n: number }>(`SELECT count(*)::int n FROM pg_proc WHERE proname = 'redeem_invite'`);
    assert.equal(fns.rows[0]!.n, 1, 'the old signature is gone');
    await assert.doesNotReject(applyMigration(old, '021_invite_serial.sql'), 'applying it twice is harmless');
  } finally {
    await old.close();
  }
});

test('fixtures validate: every invite fixture matches its door\'s schema', () => {
  const files = (folder: string, re: RegExp) => readdirSync(join(FIXTURES, folder)).filter((f) => re.test(f));
  const checks = files('01', /^invite\.check\.(?!request).*\.json$/);
  assert.deepEqual(checks.sort(), ['invite.check.alreadyin.json', 'invite.check.usable.json', 'invite.check.yours.json']);
  for (const f of checks) assert.doesNotThrow(() => CheckResponse.parse(fixture('01', f).data), f);
  for (const [folder, f] of [['01', 'invite.redeem.response.json'], ...files('00', /^redeem\.response.*\.json$/).map((f) => ['00', f])]) {
    assert.doesNotThrow(() => RedeemResponse.parse(fixture(folder!, f!).data), `${folder}/${f}`);
  }
  for (const [folder, f] of [['01', 'invite.check.request.json'], ['01', 'invite.redeem.request.json'], ['00', 'redeem.request.json']]) {
    assert.doesNotThrow(() => CodeBody.parse(fixture(folder!, f!)), `${folder}/${f}`);
  }
});
