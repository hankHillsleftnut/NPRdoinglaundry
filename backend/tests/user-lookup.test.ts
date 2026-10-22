import assert from 'node:assert/strict';
import test from 'node:test';
import { userLookupWith, type UserRowsClient } from '../src/middleware/auth.js';

const USER = '11111111-1111-4111-8111-111111111111';

/** A users table that may lack token_version (migration 005 not applied yet). */
function fakeUsers(opts: { hasTokenVersion: boolean; fail?: string; empty?: boolean; firstName?: string | null; access?: string | false }) {
  const reads: string[] = [];
  const client: UserRowsClient = {
    from: () => ({
      select: (columns: string) => ({
        eq: () => ({
          maybeSingle: async () => {
            reads.push(columns);
            if (opts.fail) return { data: null, error: { code: opts.fail } };
            if (columns.includes('access') && !opts.access) return { data: null, error: { code: '42703' } };
            if (columns.includes('token_version') && !opts.hasTokenVersion) return { data: null, error: { code: '42703' } };
            if (opts.empty) return { data: null, error: null };
            return {
              data: {
                id: USER, apple_user_id: 'apple-1', email: null, ...(opts.hasTokenVersion ? { token_version: 2 } : {}),
                ...(opts.firstName !== undefined && columns.includes('first_name') ? { first_name: opts.firstName } : {}),
                ...(opts.access && columns.includes('access') ? { access: opts.access } : {}),
              },
              error: null,
            };
          },
        }),
      }),
    }),
  };
  return { client, reads };
}

test('the lookup reads the token version', async () => {
  const { client } = fakeUsers({ hasTokenVersion: true });
  assert.deepEqual(await userLookupWith(client)(USER), { id: USER, appleUserId: 'apple-1', email: undefined, tokenVersion: 2 });
});

test("the lookup reads the first name saved at sign-in, and no name is no field", async () => {
  const { client, reads } = fakeUsers({ hasTokenVersion: true, firstName: 'Sam' });
  assert.equal((await userLookupWith(client)(USER))?.firstName, 'Sam');
  assert.ok(reads[0]!.split(', ').includes('first_name'), 'first_name is selected');
  const unnamed = await userLookupWith(fakeUsers({ hasTokenVersion: true, firstName: null }).client)(USER);
  assert.equal(unnamed !== null && 'firstName' in unnamed, false);
});

// Deploy order must not matter: the server can reach production before 005 does.
test('before migration 005, the lookup falls back to the old columns instead of failing every sign-in', async () => {
  const { client, reads } = fakeUsers({ hasTokenVersion: false });
  const warn = console.warn;
  console.warn = () => undefined;
  try {
    assert.deepEqual(await userLookupWith(client)(USER), { id: USER, appleUserId: 'apple-1', email: undefined });
  } finally {
    console.warn = warn;
  }
  assert.equal(reads.length, 3, 'with access, then without it, then the old columns');
});

test('after migration 007, the lookup reads the access state', async () => {
  const { client, reads } = fakeUsers({ hasTokenVersion: true, access: 'waitlisted' });
  assert.equal((await userLookupWith(client)(USER))?.access, 'waitlisted');
  assert.equal(reads.length, 1);
});

test('before migration 007, there is no access state (the gate lets everyone through, as before)', async () => {
  const { client } = fakeUsers({ hasTokenVersion: true });
  const warn = console.warn;
  console.warn = () => undefined;
  try {
    const user = await userLookupWith(client)(USER);
    assert.equal(user !== null && 'access' in user, false);
    assert.equal(user?.tokenVersion, 2, 'and the 005 columns still load');
  } finally {
    console.warn = warn;
  }
});

test('an access value the code does not know is treated as suspended, never as a way in', async () => {
  const { client } = fakeUsers({ hasTokenVersion: true, access: 'superuser' });
  assert.equal((await userLookupWith(client)(USER))?.access, 'suspended');
});

test('a missing user is null; any other database error throws (a 500, not a sign-out)', async () => {
  assert.equal(await userLookupWith(fakeUsers({ hasTokenVersion: true, empty: true }).client)(USER), null);
  await assert.rejects(userLookupWith(fakeUsers({ hasTokenVersion: true, fail: '08006' }).client)(USER), /user lookup failed \(08006\)/);
});
