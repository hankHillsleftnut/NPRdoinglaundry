import assert from 'node:assert/strict';
import type { AddressInfo } from 'node:net';
import test from 'node:test';
import express from 'express';

// The route module reads config at import, so env is set before importing it
// (dynamic import below); these placeholders are never real keys. The Supabase
// URL points at a closed port, so a test that reached the database would fail.
for (const key of ['SUPABASE_URL', 'SUPABASE_SERVICE_KEY', 'SUPABASE_ANON_KEY', 'ANTHROPIC_API_KEY', 'OPENAI_API_KEY',
  'JWT_SECRET', 'AGENT_SERVICE_URL', 'INTERNAL_API_SECRET']) {
  process.env[key] ??= key.endsWith('_URL') ? 'http://127.0.0.1:9' : 'test-only-not-a-key';
}

// BE0.0 (backend-reference §0 finding 7): the Idempotency-Key had no length cap.
test('a key over 128 characters is refused before anything is stored', async () => {
  const { contentRouter, MAX_IDEMPOTENCY_KEY_LENGTH } = await import('../src/routes/content.js');
  const app = express();
  app.use(express.json());
  app.use('/content', (req, _res, next) => { req.user = { id: 'user-1', appleUserId: 'apple-1' }; next(); }, contentRouter);
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', () => resolve()));
  const { port } = server.address() as AddressInfo;
  try {
    const res = await fetch(`http://127.0.0.1:${port}/content`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Idempotency-Key': 'k'.repeat(MAX_IDEMPOTENCY_KEY_LENGTH + 1) },
      body: JSON.stringify({ contentType: 'journal_entry', content: 'test entry' }),
    });
    assert.equal(res.status, 400);
    assert.deepEqual(await res.json(), { success: false, error: 'Idempotency-Key too long' });
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});
