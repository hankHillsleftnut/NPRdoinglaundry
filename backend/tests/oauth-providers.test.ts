import { test } from 'node:test';
import assert from 'node:assert/strict';

// Config placeholders come from tests/support/env.ts (npm test --import).

test('one Google sign-in covers Docs, Gmail, YouTube and Calendar, read-only', async () => {
  const { GOOGLE_COMBINED_MEMBERS, getOAuthProvider } = await import('../src/services/oauth-providers.js');
  assert.deepEqual([...GOOGLE_COMBINED_MEMBERS], ['google_docs', 'gmail', 'youtube', 'google_calendar']);
  const google = getOAuthProvider('google');
  assert.ok(google.scopes.includes('https://www.googleapis.com/auth/calendar.readonly'));
  assert.ok(google.scopes.every((s: string) => !/auth\/(calendar|gmail\.modify|drive)$/.test(s)), 'no write access anywhere');
  for (const member of GOOGLE_COMBINED_MEMBERS) {
    assert.ok(getOAuthProvider(member), `${member} has its own provider entry for its connection`);
  }
});
