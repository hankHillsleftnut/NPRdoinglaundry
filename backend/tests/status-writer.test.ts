import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

/**
 * The agent is the only writer of a row's outcome. When the backend also wrote
 * `completed` or `failed`, it overwrote the agent's retry scheduling, and 2,024
 * rows were stranded (18 October 2026). An onboarding path still did it until
 * this test was added.
 *
 * A source scan, so it catches a new route as well as the existing ones.
 */

function sourceFiles(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    return statSync(path).isDirectory() ? sourceFiles(path) : path.endsWith('.ts') ? [path] : [];
  });
}

/**
 * Rows the agent never ingests, stored already final, so there is no outcome of
 * the agent's to overwrite. Each entry names its reason.
 *   onboarding/store.ts: a first-run answer (BE2.2b.min) is read by the brain only
 *   through the composed onboarding_profile; stored `completed` and never handed to
 *   ingest, so the onboarding pipeline doesn't wait on it as pending.
 */
const NEVER_INGESTED = [join('src', 'onboarding', 'store.ts')];

test('the backend never records an ingest outcome; only the agent does', () => {
  const offenders = sourceFiles(join(process.cwd(), 'src')).filter((file) =>
    !NEVER_INGESTED.some((allowed) => file.endsWith(allowed)) &&
    /processing_status:\s*['"](completed|failed)['"]/.test(readFileSync(file, 'utf8')),
  );
  assert.deepEqual(offenders, [], 'these files write a final status the agent owns');
});
