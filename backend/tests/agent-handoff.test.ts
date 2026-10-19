import assert from 'node:assert/strict';
import test from 'node:test';
import { handOffToAgent } from '../src/services/agent-handoff.js';

/**
 * The bug these guard against: when agent ingestion failed, the upload route
 * wrote a bare `failed` over the agent's own retry scheduling -- no attempt
 * count, no retry time, no failure kind. All 2,024 rows found stranded in
 * production on 18 October 2026 had exactly that signature, and none was ever
 * retried.
 *
 * handOffToAgent is never given a database client, so it cannot write status.
 * These tests pin the rest of the contract: it never throws, and it reports.
 */

test('an unreachable agent does not fail the upload', async () => {
  const logged: unknown[] = [];

  // The agent being down must not turn into a failed upload, and must not
  // throw out of a fire-and-forget callback, where nothing would catch it.
  await assert.doesNotReject(
    handOffToAgent(
      async () => {
        throw new Error('connect ECONNREFUSED');
      },
      { userId: 'u', rawContentIds: ['r'] },
      (_message, error) => logged.push(error),
    ),
  );

  assert.equal(logged.length, 1, 'the failure is reported, not swallowed');
});

test('the agent is asked to process exactly the rows handed over', async () => {
  const calls: unknown[] = [];

  await handOffToAgent(
    async (args) => {
      calls.push(args);
    },
    { userId: 'u', rawContentIds: ['r1'] },
    () => {},
  );

  assert.deepEqual(calls, [{ userId: 'u', rawContentIds: ['r1'] }]);
});

test('a tripwire if the handoff gains a database client', () => {
  // A tripwire, not a guarantee -- worth being precise about. Function.length
  // counts parameters up to the first one with a default, so this catches the
  // usual way a dependency is added (a required argument before the optional
  // `log`) but not a database client tacked on after it. The real protection is
  // the comment on handOffToAgent explaining why the client is absent. The agent
  // records success and failure; a second writer here is what stranded the
  // backlog.
  assert.equal(
    handOffToAgent.length,
    2,
    'handOffToAgent(ingest, args, log?) -- adding a database client here reintroduces the bug',
  );
});
