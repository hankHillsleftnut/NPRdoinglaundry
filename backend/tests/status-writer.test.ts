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

test('the backend never records an ingest outcome; only the agent does', () => {
  const offenders = sourceFiles(join(process.cwd(), 'src')).filter((file) =>
    /processing_status:\s*['"](completed|failed)['"]/.test(readFileSync(file, 'utf8')),
  );
  assert.deepEqual(offenders, [], 'these files write a final status the agent owns');
});
