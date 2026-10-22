/**
 * BE0.12: the door suite on each invite door, against a real Postgres
 * (PGlite, migration 007), with each happy path equal to its contract 00
 * fixture. Suites share one database, in this order: "your invites" runs
 * before redeem gives the suite's person any.
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { before } from 'node:test';
import { asServiceRole, freshDatabase, type PGlite } from './support/database.js';
import { pgliteRpc } from './support/pglite-rpc.js';
import { doorSuite } from './support/door-suite.js';
import { supabaseAccessStore, type AccessStore } from '../src/access/store.js';
import { supabaseInviteStore, type InviteStore } from '../src/invites/store.js';
import { hashCode, newCode, sealCode } from '../src/invites/codes.js';

const FIXTURES = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '00');
const fixture = (name: string) => (JSON.parse(readFileSync(join(FIXTURES, name), 'utf8')) as { data: unknown }).data;
const USER = '11111111-1111-4111-8111-111111111111';
const OTHER = '22222222-2222-4222-8222-222222222222';
const CODE = newCode(() => Buffer.from('000000000000000042', 'hex'));

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
  for (const id of [USER, OTHER]) await db.query(`INSERT INTO users (id, apple_user_id, access) VALUES ($1, $2, 'waitlisted')`, [id, `apple-${id}`]);
  await db.query(`INSERT INTO invites (code_hash, code_ciphertext, kind) VALUES ($1, $2, 'founder')`, [hashCode(CODE), sealCode(CODE, process.env.INVITE_CODE_KEY ?? '')]);
});
const stores = () => ({ access, invites });

doorSuite({
  method: 'GET', path: '/v2/access', bucket: 'read', openToWaitlisted: true,
  invalid: { query: 'userId=someone' },
  expect: () => fixture('access.member.json'),
  stores,
});

doorSuite({
  method: 'GET', path: '/v2/invites/mine', bucket: 'read', openToWaitlisted: true,
  invalid: { query: 'all=true' },
  expect: () => ({ invites: [] }),
  stores,
});

doorSuite({
  method: 'POST', path: '/v2/waitlist', bucket: 'write', openToWaitlisted: true,
  validBody: JSON.parse(readFileSync(join(FIXTURES, 'waitlist.request.json'), 'utf8')),
  invalid: { body: { reason: 'x'.repeat(281) } },
  // The person is waitlisted in the database and the token, as the app's waitlist screen sees them.
  setup: (h, userId) => { h.users.set(userId, { ...h.users.get(userId)!, access: 'waitlisted' }); },
  expect: () => fixture('waitlist.response.json'),
  stores,
});

doorSuite({
  method: 'POST', path: '/v2/invites/redeem', bucket: 'redeem', openToWaitlisted: true,
  validBody: { code: CODE },
  invalid: { body: { code: 42 } },
  setup: (h, userId) => { h.users.set(userId, { ...h.users.get(userId)!, access: 'waitlisted' }); },
  // A founder invite (no inviter): the minimal fixture. Retries by the same person get the same answer.
  expect: () => fixture('redeem.response.minimal.json'),
  stores,
});
