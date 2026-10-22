import assert from 'node:assert/strict';
import type { AddressInfo } from 'node:net';
import test from 'node:test';
import express from 'express';

for (const key of ['SUPABASE_URL', 'SUPABASE_SERVICE_KEY', 'SUPABASE_ANON_KEY', 'ANTHROPIC_API_KEY', 'OPENAI_API_KEY',
  'JWT_SECRET', 'AGENT_SERVICE_URL', 'INTERNAL_API_SECRET']) {
  process.env[key] ??= key.endsWith('_URL') ? 'http://127.0.0.1:9' : 'test-only-not-a-key';
}

const DB_ERROR = 'column podcast_episodes.summary_embedding does not exist (row: "went for a long walk")';

// BE0.3 (backend-reference §11): 500s on /podcasts returned err.message (raw database text).
test('podcast route failures answer a generic message and report the detail', async () => {
  const { createPodcastsRouter } = await import('../src/routes/podcasts.js');
  const reported: unknown[] = [];
  const fail = async (): Promise<never> => { throw new Error(DB_ERROR); };
  const app = express();
  app.use(express.json());
  app.use((req, _res, next) => { req.user = { id: 'user-1', appleUserId: 'apple-1' }; next(); });
  app.use('/podcasts', createPodcastsRouter({
    listPodcastEpisodes: fail, getPodcastEpisode: fail, getLatestEpisode: fail, generateAgentPodcast: fail,
    report: (e) => reported.push(e),
  }));
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', () => resolve()));
  const { port } = server.address() as AddressInfo;
  const error = console.error;
  const logged: string[] = [];
  console.error = (...args: unknown[]) => { logged.push(args.map(String).join(' ')); };
  try {
    for (const [method, path, message] of [
      ['GET', '/podcasts', 'Failed to list episodes'],
      ['GET', '/podcasts/latest', 'Failed to get latest episode'],
      ['GET', '/podcasts/ep-1', 'Failed to get episode'],
      ['POST', '/podcasts/generate', 'Failed to generate episode'],
    ] as const) {
      const res = await fetch(`http://127.0.0.1:${port}${path}`, { method, headers: { 'Content-Type': 'application/json' }, body: method === 'POST' ? '{}' : undefined });
      assert.equal(res.status, 500, path);
      assert.deepEqual(await res.json(), { success: false, error: message }, path);
    }
    assert.equal(reported.length, 4);
    assert.ok((reported[0] as Error).message.includes('summary_embedding'), 'the full error goes to Sentry');
    assert.equal(logged.length, 4);
    for (const line of logged) {
      assert.equal(line.includes('walk'), false, 'no words in the log');
      assert.equal(line.includes('summary_embedding'), false, 'no database text in the log');
    }
    assert.equal(logged[0], '[Podcasts] List failed (Error)');
  } finally {
    console.error = error;
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});
