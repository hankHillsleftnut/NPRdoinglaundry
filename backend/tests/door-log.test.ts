import assert from 'node:assert/strict';
import test from 'node:test';
import { createLog, DOOR_ERROR_CODES, DOOR_LOG_FIELDS, doorLogLine, type DoorErrorCode, type DoorLogLine } from '../src/utils/log.js';

const USER = '9c1d6c0e-3f7a-4b8e-9d2a-1b2c3d4e5f60';
const ENTRY_TEXT = 'went for a long walk and thought about the move';

function capture() {
  const lines: string[] = [];
  return { log: createLog((l) => lines.push(l)), lines };
}

// The privacy rule (context.md §3) held by the type, not by care: if a field is
// ever added, this test fails until someone decides it can't carry text.
test('the door log type has no field that can carry text', () => {
  assert.deepEqual([...DOOR_LOG_FIELDS], ['door', 'userId', 'status', 'code', 'ms', 'agentMs', 'costUsd', 'appVersion']);
  const full: Required<DoorLogLine> = {
    door: 'entries.create', userId: USER, status: 200, code: 'rate_limited', ms: 12, agentMs: 8, costUsd: 0.0123, appVersion: '1.0 (42)',
  };
  assert.deepEqual(Object.keys(doorLogLine(full)), [...DOOR_LOG_FIELDS]);
});

test('one JSON line per request, with the values given', () => {
  const { log, lines } = capture();
  log.door({ door: 'entries.create', userId: USER, status: 201, ms: 34, agentMs: 20, costUsd: 0.002, appVersion: '1.0 (42)' });
  assert.equal(lines.length, 1);
  assert.ok(lines[0]!.endsWith('\n'));
  assert.equal(lines[0]!.trimEnd().includes('\n'), false, 'a single line');
  assert.deepEqual(JSON.parse(lines[0]!), {
    door: 'entries.create', userId: USER, status: 201, ms: 34, agentMs: 20, costUsd: 0.002, appVersion: '1.0 (42)',
  });
});

test('no content reaches the log, even through a string field or a cast', () => {
  const { log, lines } = capture();
  log.door({
    door: ENTRY_TEXT, userId: ENTRY_TEXT, status: 500, code: ENTRY_TEXT as DoorErrorCode, ms: 1, appVersion: ENTRY_TEXT,
    // A caller that casts past the type to sneak a field in.
    ...({ message: ENTRY_TEXT, body: { text: ENTRY_TEXT } } as object),
  } as DoorLogLine);
  const line = lines[0]!;
  assert.equal(line.includes('walk'), false, 'the words never appear');
  const parsed = JSON.parse(line) as Record<string, unknown>;
  assert.deepEqual(Object.keys(parsed).filter((k) => !(DOOR_LOG_FIELDS as readonly string[]).includes(k)), [], 'no extra fields');
  assert.equal(parsed.door, 'invalid');
  assert.equal(parsed.userId, 'invalid');
  assert.equal(parsed.code, 'invalid');
  assert.equal(parsed.appVersion, 'invalid');
});

test('an agent error message in the code field is refused', () => {
  const line = doorLogLine({ door: 'briefs.latest', userId: USER, status: 502, code: 'relation "daily_briefs" does not exist' as DoorErrorCode, ms: 5 });
  assert.equal(line.code, 'invalid');
});

// Integrator review of #64: a slug-shaped word is still content; only the contract's codes pass.
test('a single word that is not an error code, like "pregnant", is refused', () => {
  assert.equal(doorLogLine({ door: 'ping', userId: USER, status: 400, code: 'pregnant' as DoorErrorCode, ms: 1 }).code, 'invalid');
  for (const code of DOOR_ERROR_CODES) {
    assert.equal(doorLogLine({ door: 'ping', userId: USER, status: 400, code, ms: 1 }).code, code);
  }
});

test('numbers that are not finite are written as null', () => {
  const line = doorLogLine({ door: 'ping', userId: USER, status: Number.NaN, ms: Number.POSITIVE_INFINITY, costUsd: '3' as unknown as number });
  assert.equal(line.status, null);
  assert.equal(line.ms, null);
  assert.equal(line.costUsd, null);
});

test('optional fields are left out when not given', () => {
  assert.deepEqual(Object.keys(doorLogLine({ door: 'ping', userId: USER, status: 200, ms: 1 })), ['door', 'userId', 'status', 'ms']);
});

test('app versions in the contract format are kept, including dotted build numbers', () => {
  for (const v of ['1.0 (42)', '1.1 (55)', '2.0', '10.3.1 (12345678)', '1.0 (1.2.3)']) {
    assert.equal(doorLogLine({ door: 'ping', userId: USER, status: 200, ms: 1, appVersion: v }).appVersion, v);
  }
});

// Integrator review of #64: "1imsosadtoday" matched the old pattern.
test('an app version with letters in it is refused', () => {
  for (const v of ['1imsosadtoday', '1.0 (sad)', '1.0beta', 'v1.0']) {
    assert.equal(doorLogLine({ door: 'ping', userId: USER, status: 200, ms: 1, appVersion: v }).appVersion, 'invalid', v);
  }
});

test('public doors log a null user; a malformed user id is invalid', () => {
  assert.equal(doorLogLine({ door: 'auth.apple', userId: null, status: 200, ms: 1 }).userId, null);
  assert.equal(doorLogLine({ door: 'ping', userId: 'not-a-uuid', status: 200, ms: 1 }).userId, 'invalid');
});

test('a failing log write never throws into the request', () => {
  const broken = createLog(() => { throw new Error('EPIPE'); });
  assert.doesNotThrow(() => broken.door({ door: 'ping', userId: USER, status: 200, ms: 1 }));
});
