/**
 * BE2.0a over HTTP on the real app (harness), with invites on a real Postgres
 * (PGlite, migrations 007, 021 and 024, run as service_role): the signed-out
 * preview prints a live code's face and says nothing at all about any other
 * code. It is a public enumeration surface, so the identical answer and the
 * per-address limit are the whole point.
 */
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import test, { after, before } from 'node:test';
import { asServiceRole, freshDatabase, insertUser, type PGlite } from './support/database.js';
import { pgliteRpc } from './support/pglite-rpc.js';
import { startHarness, type Harness } from './support/harness.js';
import { supabaseAccessStore, type AccessStore } from '../src/access/store.js';
import { supabaseInviteStore, type InviteStore } from '../src/invites/store.js';
import { hashCode, newCode, sealCode } from '../src/invites/codes.js';
import { PreviewResponse } from '../src/invites/public.js';
import { DOOR_LIMITS } from '../src/doors/limits.js';

const KEY = process.env.INVITE_CODE_KEY ?? '';
const FIXTURES = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '01');
const fixture = (name: string) => JSON.parse(readFileSync(join(FIXTURES, name), 'utf8')) as { data: unknown };
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

let seq = 5000;
const nextCode = () => newCode(() => { const b = Buffer.alloc(9); b.writeUInt32BE(++seq, 5); return b; });

async function person(h: Harness, firstName?: string): Promise<string> {
  const id = await insertUser(db);
  await db.query(`UPDATE users SET access = 'member', first_name = $2 WHERE id = $1`, [id, firstName ?? null]);
  h.users.set(id, { id, appleUserId: `apple-${id}`, access: 'member', ...(firstName ? { firstName } : {}) });
  return id;
}

async function invite(opts: { kind?: 'founder' | 'member' | 'review'; owner?: string; expiresAt?: string; revoked?: boolean; usedBy?: string; createdAt?: string } = {}): Promise<string> {
  const code = nextCode();
  await db.query(
    `INSERT INTO invites (code_hash, code_ciphertext, kind, owner_user_id, expires_at, revoked_at, used_by_user_id, used_at, created_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
    [hashCode(code), sealCode(code, KEY), opts.kind ?? 'founder', opts.owner ?? null, opts.expiresAt ?? null,
      opts.revoked ? new Date(T0).toISOString() : null, opts.usedBy ?? null, opts.usedBy ? new Date(T0).toISOString() : null, opts.createdAt ?? '2026-10-19T10:00:00.000Z'],
  );
  return code;
}

const harness = () => startHarness({ access, invites, now: T0 });
const preview = async (h: Harness, code: string) => {
  const res = await fetch(`${h.url}/public/invites/${encodeURIComponent(code)}`);
  return { status: res.status, headers: res.headers, body: await res.json() as unknown };
};

test('a live invite previews its inviter, serial and date: the contract fixture exactly', async () => {
  const h = await harness();
  try {
    const priya = await person(h, 'priya');
    await db.query(`SELECT setval('invite_serial_seq', 412, false)`);
    const live = await invite({ kind: 'member', owner: priya });
    const res = await preview(h, live);
    assert.equal(res.status, 200);
    assert.deepEqual(res.body, fixture('invite.preview.live.json'));
    assert.equal(res.headers.get('cache-control'), 'no-store');
    assert.equal(res.headers.get('set-cookie'), null, 'no cookies');
    assert.deepEqual(await preview(h, `${live.slice(0, 4).toLowerCase()}-${live.slice(4)}`).then((r) => r.body), res.body, 'as typed: case and dashes ignored');
    const review = await invite({ kind: 'review' });
    assert.deepEqual((await preview(h, review)).body, { success: true, data: { live: true, face: { from: null, kind: 'review', serial: 413, issuedOn: '2026-10-19' } } }, 'a review invite has no name');
    assert.equal(h.logLines.join('').includes('priya'), false, 'no name in the log');
    assert.equal(h.logLines.join('').includes(live), false, 'no code in the log');
    assert.equal(h.logLines.some((l) => l.includes('invites.preview')), true, 'but the door is logged');
  } finally {
    await h.close();
  }
});

test('a used, revoked, expired, unknown or malformed code all answer the same body (*)', async () => {
  const h = await harness();
  try {
    const owner = await person(h, 'priya');
    const neutral = fixture('invite.preview.notlive.json');
    const cases: [string, string][] = [
      ['used', await invite({ kind: 'member', owner, usedBy: await person(h, 'sam') })],
      ['revoked', await invite({ kind: 'member', owner, revoked: true })],
      ['expired', await invite({ kind: 'member', owner, expiresAt: new Date(T0 - 1000).toISOString() })],
      ['expiring now', await invite({ kind: 'member', owner, expiresAt: new Date(T0).toISOString() })],
      ['unknown', nextCode()],
      ['malformed', 'not a code'],
      ['outside the alphabet', 'U'.repeat(13)],
      ['too long', 'x'.repeat(300)],
      ['markup', '<script>alert(1)</script>'],
    ];
    for (const [label, code] of cases) {
      const res = await preview(h, code);
      assert.equal(res.status, 200, label);
      assert.deepEqual(res.body, neutral, label);
    }
    assert.equal(JSON.stringify(h.logLines).includes('priya'), false);
    assert.equal((await preview(h, await invite({ kind: 'member', owner, expiresAt: new Date(T0 + 60_000).toISOString() }))).body && true, true);
    assert.equal((fixture('invite.preview.notlive.json').data as { live: boolean }).live, false);
  } finally {
    await h.close();
  }
});

test('the preview never opens the sealed code (*)', async () => {
  const h = await harness();
  try {
    const live = await invite();
    await db.query(`UPDATE invites SET code_ciphertext = 'not-a-sealed-code' WHERE code_hash = $1`, [hashCode(live)]);
    assert.equal((await preview(h, live)).status, 200);
    assert.equal(((await preview(h, live)).body as { data: { live: boolean } }).data.live, true, 'garbage in the sealed column changes nothing');
    const { rows } = await db.query<{ def: string }>(`SELECT pg_get_functiondef('invite_face(text, timestamptz)'::regprocedure) AS def`);
    assert.equal(rows[0]!.def.includes('code_ciphertext'), false, 'the function never names the sealed code');
  } finally {
    await h.close();
  }
});

test('the preview is rate-limited per address, with the contract envelope', async () => {
  const h = await harness();
  try {
    const max = DOOR_LIMITS.buckets.invitePreview[0]!.max;
    assert.equal(max, 30, "the contract's number: 30 a minute");
    for (let i = 0; i < max; i++) assert.equal((await preview(h, nextCode())).status, 200, `preview ${i + 1}`);
    const over = await preview(h, nextCode());
    assert.equal(over.status, 429);
    const body = over.body as { success: boolean; error: { code: string; retryAfterSeconds?: number } };
    assert.equal(body.error.code, 'rate_limited');
    assert.ok((body.error.retryAfterSeconds ?? 0) > 0);
    assert.equal(over.headers.get('retry-after'), String(body.error.retryAfterSeconds));
    assert.equal((await fetch(`${h.url}/i/${nextCode()}`)).status, 200, "the link page's bucket is its own");
    h.clock.now += 61_000;
    assert.equal((await preview(h, nextCode())).status, 200, 'a minute later');
  } finally {
    await h.close();
  }
});

test('fixtures validate: both preview fixtures match the schema, and the live one is a full face', () => {
  for (const file of ['invite.preview.live.json', 'invite.preview.notlive.json']) {
    assert.doesNotThrow(() => PreviewResponse.parse(fixture(file).data), file);
  }
  const live = PreviewResponse.parse(fixture('invite.preview.live.json').data);
  assert.equal(live.live, true);
  assert.deepEqual(Object.keys((live as { face: object }).face).sort(), ['from', 'issuedOn', 'kind', 'serial']);
});
