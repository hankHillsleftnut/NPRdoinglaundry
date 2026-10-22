/**
 * BE0.12 over HTTP on the real app (harness), with access and invites on a
 * real Postgres (PGlite, migration 007's functions, run as service_role).
 * The row lock that keeps two redemptions of one code apart is proven on a
 * two-connection server in sessions-lock.test.ts.
 */
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import type { AddressInfo } from 'node:net';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import test, { after, before } from 'node:test';
import express from 'express';
import { asServiceRole, applyMigration, freshDatabase, insertUser, type PGlite } from './support/database.js';
import { pgliteRpc } from './support/pglite-rpc.js';
import { startHarness, type Harness } from './support/harness.js';
import { supabaseAccessStore, type AccessState, type AccessStore } from '../src/access/store.js';
import { supabaseInviteStore, type InviteStore } from '../src/invites/store.js';
import { hashCode, newCode, normaliseCode, openCode, sealCode, displayCode } from '../src/invites/codes.js';
import { createPublicInviteRouter, linkPage } from '../src/invites/public.js';
import { MemoryLimiter } from '../src/doors/limits.js';

const KEY = process.env.INVITE_CODE_KEY ?? '';
const FIXTURES = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '00');
const fixture = (name: string) => (JSON.parse(readFileSync(join(FIXTURES, name), 'utf8')) as { data: unknown }).data;
const T0 = Date.parse('2026-10-22T09:00:00.000Z');
let db: PGlite;
let access: AccessStore;
let invites: InviteStore;

/** Every store call runs as service_role, as the backend does in production. */
function asService<T extends object>(store: T): T {
  return Object.fromEntries(Object.entries(store).map(([k, fn]) => [k, (...a: unknown[]) => asServiceRole(db, () => (fn as (...x: unknown[]) => Promise<unknown>)(...a))])) as T;
}

before(async () => {
  db = await freshDatabase();
  access = asService(supabaseAccessStore(pgliteRpc(db)));
  invites = asService(supabaseInviteStore(pgliteRpc(db)));
});
after(async () => { await db.close(); });

let seq = 0;
/** Deterministic codes: a counter, no randomness. */
const nextCode = () => newCode(() => { const b = Buffer.alloc(9); b.writeUInt32BE(++seq, 5); return b; });

/** A person in the database and in the harness's user table, with this access state. */
async function person(h: Harness, state: AccessState, firstName?: string): Promise<string> {
  const id = await insertUser(db);
  await db.query(`UPDATE users SET access = $2, first_name = $3 WHERE id = $1`, [id, state, firstName ?? null]);
  h.users.set(id, { id, appleUserId: `apple-${id}`, access: state, ...(firstName ? { firstName } : {}) });
  return id;
}

/** An invite with a known code. */
async function invite(opts: { kind?: 'founder' | 'member' | 'review'; owner?: string; expiresAt?: string; revoked?: boolean } = {}): Promise<string> {
  const code = nextCode();
  await db.query(
    `INSERT INTO invites (code_hash, code_ciphertext, kind, owner_user_id, expires_at, revoked_at) VALUES ($1, $2, $3, $4, $5, $6)`,
    [hashCode(code), sealCode(code, KEY), opts.kind ?? 'founder', opts.owner ?? null, opts.expiresAt ?? null, opts.revoked ? new Date(T0).toISOString() : null],
  );
  return code;
}

const harness = () => startHarness({ access, invites, now: T0 });
const as = (h: Harness, id: string) => ({ Authorization: `Bearer ${h.asUser(id)}` });
const redeem = (h: Harness, id: string, code: string, extra: Record<string, string> = {}) => h.request('POST', '/v2/invites/redeem', { code }, { ...as(h, id), ...extra });
const code = (body: unknown) => (body as { error?: { code?: string } }).error?.code;
const data = <T>(body: unknown) => (body as { data: T }).data;
const memberInvites = async (owner: string) =>
  (await db.query<{ n: number }>(`SELECT count(*)::int n FROM invites WHERE owner_user_id = $1 AND kind = 'member'`, [owner])).rows[0]!.n;

test('existing users are grandfathered as members; a new sign-in is waitlisted', async () => {
  const old = await freshDatabase({ before: '007_invites.sql' });
  try {
    const before007 = await insertUser(old);
    await applyMigration(old, '007_invites.sql');
    const after007 = await insertUser(old);
    const { rows } = await old.query<{ id: string; access: string }>(`SELECT id, access FROM users`);
    assert.deepEqual(Object.fromEntries(rows.map((r) => [r.id, r.access])), { [before007]: 'member', [after007]: 'waitlisted' });
  } finally {
    await old.close();
  }
});

test('a single-use invite works once, even with two redemptions at once', async () => {
  const h = await harness();
  try {
    const c = await invite();
    const [a, b] = [await person(h, 'waitlisted'), await person(h, 'waitlisted')];
    const results = await Promise.all([redeem(h, a, c), redeem(h, b, c)]);
    assert.deepEqual(results.map((r) => r.status).sort(), [200, 400]);
    assert.deepEqual(results.map((r) => code(r.body) ?? 'ok').sort(), ['invite_used', 'ok']);
    const spent = await db.query<{ serial: number; n: number }>(`SELECT serial::int AS serial, count(*) OVER ()::int AS n FROM invites WHERE used_by_user_id IS NOT NULL`);
    assert.equal(spent.rows[0]!.n, 1, 'one invite spent');
    const winner = results.find((r) => r.status === 200)!;
    assert.equal(data<{ invite: { serial: number } }>(winner.body).invite.serial, spent.rows[0]!.serial, 'and the winner holds its serial');
    const c2 = await invite();
    assert.equal((await redeem(h, a, c2)).status, 200, 'a second code for someone already in spends nothing');
    const third = await person(h, 'waitlisted');
    assert.equal((await redeem(h, third, c2)).status, 200, 'so it still works for someone else');
  } finally {
    await h.close();
  }
});

test('redeeming gives exactly three invites, and a retried redeem never gives six', async () => {
  const h = await harness();
  try {
    const owner = await person(h, 'member', 'priya');
    await db.query(`SELECT setval('invite_serial_seq', 412, false)`);
    const c = await invite({ kind: 'member', owner });
    const sam = await person(h, 'waitlisted');
    // 09:00Z on the 22nd is the evening of the 21st in Honolulu: the fixture's redeemedOn.
    const first = await redeem(h, sam, c, { 'X-Time-Zone': 'Pacific/Honolulu' });
    assert.equal(first.status, 200);
    assert.deepEqual(data(first.body), fixture('redeem.response.json'), 'the contract fixture exactly');
    const retries = await Promise.all([redeem(h, sam, c), redeem(h, sam, c), redeem(h, sam, `${displayCode(c).toLowerCase()} `)]);
    for (const r of retries) assert.deepEqual(data(r.body), fixture('redeem.response.json'), 'the same answer, with the stored date, from any zone');
    assert.equal(await memberInvites(sam), 3);
    const other = await invite();
    await redeem(h, sam, other);
    assert.equal(await memberInvites(sam), 3, 'another code later gives nothing more');
    const { rows } = await db.query<{ access: string; status: string | null }>(
      `SELECT u.access, w.status FROM users u LEFT JOIN waitlist w ON w.user_id = u.id WHERE u.id = $1`, [sam]);
    assert.equal(rows[0]!.access, 'approved');
  } finally {
    await h.close();
  }
});

test("a revoked or expired invite can't be used, and a code that isn't one is invalid", async () => {
  const h = await harness();
  try {
    const p = await person(h, 'waitlisted');
    assert.equal(code((await redeem(h, p, await invite({ revoked: true }))).body), 'invite_invalid');
    assert.equal(code((await redeem(h, p, await invite({ expiresAt: new Date(T0 - 1000).toISOString() }))).body), 'invite_expired');
    assert.equal(code((await redeem(h, p, nextCode())).body), 'invite_invalid', 'well formed, never issued');
    assert.equal(code((await redeem(h, p, 'not a code')).body), 'invite_invalid');
    assert.equal(code((await redeem(h, p, 'U'.repeat(13))).body), 'invite_invalid', 'outside the alphabet');
    assert.equal((await db.query<{ access: string }>(`SELECT access FROM users WHERE id = $1`, [p])).rows[0]!.access, 'waitlisted');
    const live = await invite({ expiresAt: new Date(T0 + 60_000).toISOString() });
    assert.equal((await redeem(h, await person(h, 'waitlisted'), live)).status, 200, 'an invite before its expiry works');
  } finally {
    await h.close();
  }
});

test("the gate refuses waitlisted users everywhere but contract 00 §4's own doors", async () => {
  const h = await harness();
  try {
    const w = await person(h, 'waitlisted');
    const ping = await h.request('GET', '/v2/ping', undefined, as(h, w));
    assert.equal(ping.status, 403);
    assert.equal(code(ping.body), 'invite_required');
    assert.deepEqual(data((await h.request('GET', '/v2/invites/mine', undefined, as(h, w))).body), { invites: [] }, 'no invites yet');
    assert.deepEqual(data((await h.request('GET', '/v2/access', undefined, as(h, w))).body), { state: 'waitlisted', onWaitlist: false });
    assert.deepEqual(data((await h.request('POST', '/v2/waitlist', { reason: 'a friend told me about it' }, as(h, w))).body), { onWaitlist: true });
    assert.deepEqual(data((await h.request('POST', '/v2/waitlist', { reason: 'again' }, as(h, w))).body), { onWaitlist: true });
    assert.deepEqual(data((await h.request('GET', '/v2/access', undefined, as(h, w))).body), { state: 'waitlisted', onWaitlist: true });
    const { rows } = await db.query<{ n: number; reason: string }>(`SELECT count(*)::int n, min(reason) reason FROM waitlist WHERE user_id = $1`, [w]);
    assert.deepEqual(rows[0], { n: 1, reason: 'a friend told me about it' }, 'once, with the first reason');

    const m = await person(h, 'member');
    assert.equal((await h.request('GET', '/v2/ping', undefined, as(h, m))).status, 200);
    assert.deepEqual(data((await h.request('POST', '/v2/waitlist', {}, as(h, m))).body), { onWaitlist: false }, 'a member is never put on the waitlist');

    const s = await person(h, 'suspended');
    for (const path of ['/v2/ping', '/v2/access']) assert.equal(code((await h.request('GET', path, undefined, as(h, s))).body), 'suspended', path);
  } finally {
    await h.close();
  }
});

test('redeem is rate-limited per user and per address', async () => {
  const h = await harness();
  try {
    const p = await person(h, 'waitlisted');
    for (let i = 0; i < 5; i++) assert.equal((await redeem(h, p, nextCode())).status, 400);
    const sixth = await redeem(h, p, nextCode());
    assert.equal(sixth.status, 429);
    assert.ok(((sixth.body as { error: { retryAfterSeconds?: number } }).error.retryAfterSeconds ?? 0) > 0);

    // 20 per 10 minutes from one address, however many people sign in there
    // (6 so far, each counted at the address before the person's own limit).
    let tries = 0;
    while (tries < 14) {
      const q = await person(h, 'waitlisted');
      for (let i = 0; i < 5 && tries < 14; i++, tries++) assert.equal((await redeem(h, q, nextCode())).status, 400);
    }
    const last = await person(h, 'waitlisted');
    assert.equal((await redeem(h, last, nextCode())).status, 429, 'the 21st from this address');
  } finally {
    await h.close();
  }
});

test("the public waitlist answers the same for new and known emails, and keeps one row per email", async () => {
  const h = await harness();
  try {
    const join = (body: Record<string, unknown>) => h.request('POST', '/public/waitlist', body);
    const first = await join({ email: 'new.person@example.com', name: 'sam', reason: 'heard about it', website: '' });
    const again = await join({ email: 'New.Person@Example.com', name: 'someone', reason: 'again' });
    const bot = await join({ email: 'bot@example.com', website: 'http://spam.example' });
    for (const r of [first, again, bot]) {
      assert.equal(r.status, 200);
      assert.deepEqual(r.body, { success: true, data: { received: true } });
    }
    const { rows } = await db.query<{ email: string; name: string }>(`SELECT email, name FROM waitlist WHERE source = 'web' ORDER BY created_at`);
    assert.deepEqual(rows, [{ email: 'new.person@example.com', name: 'sam' }], 'the first stays; the bot stored nothing');
    assert.equal(h.logLines.join('').includes('example.com'), false, 'no email in the log');
    assert.equal((await join({ email: 'not-an-email' })).status, 400);
    for (let i = 0; i < 1; i++) await join({ email: `p${i}@example.com` });
    assert.equal((await join({ email: 'late@example.com' })).status, 429, 'five an hour per address');
  } finally {
    await h.close();
  }
});

test('the link page never reveals whether a code is valid', async () => {
  const h = await harness();
  try {
    const owner = await person(h, 'member', 'priya');
    const live = await invite({ kind: 'member', owner });
    const used = await invite({ kind: 'member', owner });
    await redeem(h, await person(h, 'waitlisted'), used);
    const revoked = await invite({ kind: 'member', owner, revoked: true });
    const unknown = nextCode();
    const page = async (c: string) => {
      const res = await fetch(`${h.url}/i/${c}`);
      assert.equal(res.headers.get('set-cookie'), null, 'no cookies');
      assert.equal(res.headers.get('cache-control'), 'no-store');
      assert.equal(res.status, 200);
      return (await res.text()).replace(displayCode(c), 'CODE');
    };
    assert.ok((await page(live)).includes('priya saved you a place'), 'a live code shows who sent it');
    const neutral = await page(unknown);
    assert.equal(neutral.includes('priya'), false);
    assert.equal(await page(used), neutral, 'used looks like unknown');
    assert.equal(await page(revoked), neutral, 'revoked looks like unknown');
    const garbage = await (await fetch(`${h.url}/i/%3Cscript%3E`)).text();
    assert.equal(garbage.includes('<script>'), false, 'nothing from the path is echoed raw');
    assert.equal(linkPage({ code: null, from: '<b>x</b>', appUrl: null }).includes('<b>'), false, 'names are escaped');
  } finally {
    await h.close();
  }
});

test('approving a waitlister creates exactly one founder invite and returns its link once', async () => {
  const h = await harness();
  const { mountAdmin } = await import('../src/routes/admin-mount.js');
  const app = express();
  app.use(express.json());
  mountAdmin(app, { secret: 'test-admin-secret', publicDir: join(__dirname, '..', 'src', 'public'), invites: { invites, now: () => T0, codeKey: KEY, baseUrl: 'https://retrospect-api.onrender.com' } });
  const server = createServer(app);
  await new Promise<void>((r) => server.listen(0, '127.0.0.1', r));
  const admin = async (method: string, path: string, body?: unknown) => {
    const res = await fetch(`http://127.0.0.1:${(server.address() as AddressInfo).port}/admin${path}`, {
      method, headers: { 'x-admin-secret': 'test-admin-secret', 'Content-Type': 'application/json' }, ...(body ? { body: JSON.stringify(body) } : {}),
    });
    return { status: res.status, body: await res.json() as { data: unknown } };
  };
  try {
    const w = await person(h, 'waitlisted');
    await h.request('POST', '/v2/waitlist', {}, as(h, w));
    const waiting = (await admin('GET', '/waitlist?status=waiting')).body.data as { id: string; userId: string }[];
    const row = waiting.find((r) => r.userId === w)!;
    const approved = await admin('POST', `/waitlist/${row.id}/approve`);
    assert.equal(approved.status, 200);
    const { code: shown, link } = approved.body.data as { code: string; link: string };
    assert.match(link, /^https:\/\/retrospect-api\.onrender\.com\/i\/[0-9A-HJKMNP-TV-Z]{13}$/);
    assert.equal(normaliseCode(shown), link.slice(-13));
    assert.equal((await admin('POST', `/waitlist/${row.id}/approve`)).status, 409, 'once');
    const { rows } = await db.query<{ n: number }>(
      `SELECT count(*)::int n FROM invites i JOIN waitlist w ON w.invite_id = i.id WHERE w.id = $1 AND i.kind = 'founder'`, [row.id]);
    assert.equal(rows[0]!.n, 1);
    const list = JSON.stringify((await admin('GET', '/invites')).body);
    assert.equal(list.includes(link.slice(-13)), false, 'the code is never shown again');
    assert.equal(list.includes(hashCode(link.slice(-13))), false, 'nor its hash');
    assert.equal((await redeem(h, w, link.slice(-13))).status, 200, 'and the link lets them in');

    const made = await admin('POST', '/invites', { count: 2, kind: 'review' });
    assert.equal((made.body.data as { invites: unknown[] }).invites.length, 2);
    const ids = ((await admin('GET', '/invites')).body.data as { id: string; kind: string; usedAt: string | null }[]).filter((i) => i.kind === 'review');
    assert.equal((await admin('POST', `/invites/${ids[0]!.id}/revoke`)).status, 200);
    assert.equal((await admin('POST', `/invites/${ids[0]!.id}/revoke`)).status, 409);
    const s = await person(h, 'member');
    assert.equal((await admin('POST', `/users/${s}/suspend`)).status, 200);
    assert.equal((await db.query<{ access: string }>(`SELECT access FROM users WHERE id = $1`, [s])).rows[0]!.access, 'suspended');
    assert.equal((await admin('POST', `/users/${s}/invites`, { add: 2 })).status, 200);
    assert.equal(await memberInvites(s), 2);
    assert.equal((await admin('POST', '/waitlist/not-a-uuid/decline')).status, 400);
    const page = await fetch(`http://127.0.0.1:${(server.address() as AddressInfo).port}/dashboard/invites`);
    assert.equal(page.status, 200, 'the dashboard page is served');
  } finally {
    server.close();
    await h.close();
  }
});

test('codes are stored only as hashes, and links decrypt only while unused', async () => {
  const h = await harness();
  try {
    const sam = await person(h, 'waitlisted', 'sam');
    await redeem(h, sam, await invite());
    h.users.set(sam, { ...h.users.get(sam)!, access: 'approved' });
    const mine = data<{ invites: { id: string; link: string | null; state: string; usedBy: string | null }[] }>(
      (await h.request('GET', '/v2/invites/mine', undefined, as(h, sam))).body).invites;
    assert.equal(mine.length, 3);
    const shape = (fixture('invites-mine.json') as { invites: Record<string, unknown>[] }).invites[1]!;
    assert.deepEqual(Object.keys(mine[0]!).sort(), Object.keys(shape).sort(), "the contract fixture's fields");
    for (const i of mine) {
      assert.equal(i.state, 'unused');
      const c = i.link!.slice(-13);
      const { rows } = await db.query<{ code_hash: string; code_ciphertext: string }>(`SELECT code_hash, code_ciphertext FROM invites WHERE id = $1`, [i.id]);
      assert.equal(rows[0]!.code_hash, hashCode(c), 'stored as its hash');
      assert.equal(rows[0]!.code_ciphertext.includes(c), false, 'and sealed, never plain');
      assert.equal(openCode(rows[0]!.code_ciphertext, KEY), c);
    }
    const priya = await person(h, 'waitlisted', 'priya');
    await redeem(h, priya, mine[0]!.link!.slice(-13));
    const after = data<{ invites: { id: string; link: string | null; state: string; usedBy: string | null }[] }>(
      (await h.request('GET', '/v2/invites/mine', undefined, as(h, sam))).body).invites;
    assert.deepEqual(after.find((i) => i.id === mine[0]!.id), { ...mine[0]!, link: null, state: 'used', usedBy: 'priya' });
    const { rows } = await db.query<{ code_ciphertext: string | null }>(`SELECT code_ciphertext FROM invites WHERE id = $1`, [mine[0]!.id]);
    assert.equal(rows[0]!.code_ciphertext, null, 'cleared at use');

    // Two people: priya sees only her own three.
    h.users.set(priya, { ...h.users.get(priya)!, access: 'approved' });
    const hers = data<{ invites: { id: string }[] }>((await h.request('GET', '/v2/invites/mine', undefined, as(h, priya))).body).invites;
    assert.equal(hers.length, 3);
    assert.equal(hers.some((i) => mine.some((m) => m.id === i.id)), false);
    assert.equal(h.logLines.some((l) => mine.some((m) => l.includes(m.link!.slice(-13)))), false, 'no code in the log');
  } finally {
    await h.close();
  }
});

test('without INVITE_CODE_KEY nothing is minted: redeem is an error and spends nothing', async () => {
  const { createV2Router } = await import('../src/doors/router.js');
  const h = await startHarness({
    access, invites, now: T0,
    v2Router: (door, deps) => createV2Router(door, { ...deps, invites: { ...deps.invites, codeKey: null } }),
  });
  try {
    const c = await invite();
    const p = await person(h, 'waitlisted');
    const res = await redeem(h, p, c);
    assert.equal(res.status, 500);
    assert.equal(code(res.body), 'internal');
    const { rows } = await db.query<{ used: boolean }>(`SELECT used_by_user_id IS NOT NULL used FROM invites WHERE code_hash = $1`, [hashCode(c)]);
    assert.equal(rows[0]!.used, false);
  } finally {
    await h.close();
  }
});

test('the app-link file declares /i/* for the app, and is absent without a team id', async () => {
  const serve = async (teamId: string) => {
    const app = express();
    app.use(createPublicInviteRouter({
      invites, limiter: new MemoryLimiter(), now: () => T0, log: { door: () => undefined }, reportBug: () => undefined,
      appUrl: null, teamId, bundleId: 'com.shauryanarang.Retrospect',
    }));
    const server = createServer(app);
    await new Promise<void>((r) => server.listen(0, '127.0.0.1', r));
    try {
      const res = await fetch(`http://127.0.0.1:${(server.address() as AddressInfo).port}/.well-known/apple-app-site-association`, { redirect: 'manual' });
      return { status: res.status, type: res.headers.get('content-type'), body: res.status === 200 ? await res.json() : null };
    } finally {
      server.close();
    }
  };
  const on = await serve('ABCDE12345');
  assert.equal(on.status, 200);
  assert.match(on.type ?? '', /^application\/json/);
  assert.deepEqual(on.body, { applinks: { details: [{ appIDs: ['ABCDE12345.com.shauryanarang.Retrospect'], components: [{ '/': '/i/*', comment: 'invite links' }] }] } });
  assert.equal((await serve('')).status, 404);
});

test('the invites dashboard puts every value on the page as text, never as HTML', () => {
  const html = readFileSync(join(__dirname, '..', 'src', 'public', 'invites.html'), 'utf8');
  assert.equal(/innerHTML|outerHTML|insertAdjacentHTML|document\.write/.test(html), false);
  assert.ok(html.includes('textContent'));
});
