import assert from 'node:assert/strict';
import test from 'node:test';
import { checkSpendCap, DOOR_LIMITS, MemoryLimiter, type LimitBucket } from '../src/doors/limits.js';

const T0 = 1_800_000_000_000;
const MINUTE = 60_000;
const HOUR = 60 * MINUTE;

function fill(limiter: MemoryLimiter, user: string, bucket: LimitBucket, count: number, at: number): number {
  let allowed = 0;
  for (let i = 0; i < count; i++) if (limiter.take(user, bucket, at).ok) allowed++;
  return allowed;
}

test('the limiter allows exactly the bucket\'s limit per window and then reports retryAfter', () => {
  for (const bucket of ['read', 'write'] as const) {
    const limiter = new MemoryLimiter();
    const max = DOOR_LIMITS.buckets[bucket][0]!.max;
    assert.equal(fill(limiter, 'a', bucket, max, T0), max, `${bucket}: all ${max} allowed`);
    const refused = limiter.take('a', bucket, T0 + 1_000);
    assert.deepEqual(refused, { ok: false, retryAfterSeconds: 59 }, `${bucket}: the next waits for the oldest to age out`);
    assert.equal(limiter.take('a', bucket, T0 + MINUTE + 1).ok, true, `${bucket}: the window rolls`);
  }
});

test('the window is rolling, not fixed: requests free up one by one as they age', () => {
  const limiter = new MemoryLimiter();
  const max = DOOR_LIMITS.buckets.write[0]!.max;
  for (let i = 0; i < max; i++) assert.equal(limiter.take('a', 'write', T0 + i * 1_000).ok, true);
  assert.equal(limiter.take('a', 'write', T0 + MINUTE - 1).ok, false, 'the first request is still inside the minute');
  assert.equal(limiter.take('a', 'write', T0 + MINUTE).ok, true, 'once it is a minute old, one slot frees');
  assert.equal(limiter.take('a', 'write', T0 + MINUTE + 1).ok, false, 'and only one');
});

test('expensive doors have both a per-minute and a per-hour limit', () => {
  const limiter = new MemoryLimiter();
  const [perMinute, perHour] = DOOR_LIMITS.buckets.expensive;
  assert.equal(fill(limiter, 'a', 'expensive', perMinute!.max + 1, T0), perMinute!.max, '10 a minute');

  let allowed = perMinute!.max;
  for (let m = 1; m < 60; m++) allowed += fill(limiter, 'a', 'expensive', perMinute!.max, T0 + m * MINUTE + m);
  assert.equal(allowed, perHour!.max, '60 an hour, however they are spread');
  const refused = limiter.take('a', 'expensive', T0 + 10 * MINUTE);
  assert.deepEqual(refused, { ok: false, retryAfterSeconds: 50 * 60 }, 'told to wait for the hour, not the minute');
  assert.equal(limiter.take('a', 'expensive', T0 + HOUR).ok, true, 'the first ten age out after an hour');
});

test('another user\'s usage never affects a user\'s limit', () => {
  const limiter = new MemoryLimiter();
  fill(limiter, 'a', 'write', DOOR_LIMITS.buckets.write[0]!.max + 5, T0);
  assert.equal(limiter.take('a', 'write', T0).ok, false);
  assert.equal(limiter.take('b', 'write', T0).ok, true, 'user b is untouched');
  limiter.recordSpend('a', 20, T0);
  assert.equal(limiter.spentToday('b', T0), 0, 'and so is their spend');
});

test('buckets are separate: a full write bucket doesn\'t block reads', () => {
  const limiter = new MemoryLimiter();
  fill(limiter, 'a', 'write', DOOR_LIMITS.buckets.write[0]!.max, T0);
  assert.equal(limiter.take('a', 'write', T0).ok, false);
  assert.equal(limiter.take('a', 'read', T0).ok, true);
});

test('a refused request is not counted', () => {
  const limiter = new MemoryLimiter();
  const max = DOOR_LIMITS.buckets.write[0]!.max;
  fill(limiter, 'a', 'write', max, T0);
  for (let i = 0; i < 100; i++) limiter.take('a', 'write', T0 + 30_000);
  assert.equal(limiter.take('a', 'write', T0 + MINUTE + 1).ok, true, 'hammering while full does not extend the wait');
});

test('spend over the daily cap is reported until the window rolls', () => {
  const limiter = new MemoryLimiter();
  limiter.recordSpend('a', 10, T0);
  assert.equal(checkSpendCap(limiter, 'a', T0).over, false);
  limiter.recordSpend('a', 5, T0 + HOUR);
  assert.equal(limiter.spentToday('a', T0 + HOUR), 15);
  assert.equal(checkSpendCap(limiter, 'a', T0 + HOUR).over, true, 'at the cap');
  assert.equal(checkSpendCap(limiter, 'a', T0 + 23 * HOUR).over, true, 'still within 24 hours of both');
  assert.equal(checkSpendCap(limiter, 'a', T0 + 24 * HOUR + 1).over, false, 'the first $10 aged out');
  assert.equal(limiter.spentToday('a', T0 + 24 * HOUR + 1), 5);
  assert.equal(limiter.spentToday('a', T0 + 25 * HOUR + 1), 0);
});

test('zero, negative and non-numeric spend is ignored; a cap of 0 means no cap', () => {
  const limiter = new MemoryLimiter();
  limiter.recordSpend('a', 0, T0);
  limiter.recordSpend('a', -3, T0);
  limiter.recordSpend('a', Number.NaN, T0);
  assert.equal(limiter.spentToday('a', T0), 0);
  limiter.recordSpend('a', 100, T0);
  assert.equal(checkSpendCap(limiter, 'a', T0, 0).over, false);
});

test('users idle past their longest window are forgotten', () => {
  const limiter = new MemoryLimiter();
  limiter.take('a', 'read', T0);
  limiter.take('b', 'expensive', T0);
  limiter.take('c', 'read', T0 + 2 * HOUR);
  assert.equal(limiter.size(), 1, 'a (one-minute bucket) and b (one-hour bucket) are both gone two hours later');
});

// Contract 00 §2: spend_limited carries retryAfterSeconds.
test('over the spend cap, the wait is until enough of the oldest spend ages out', () => {
  const limiter = new MemoryLimiter();
  limiter.recordSpend('a', 6, T0);
  limiter.recordSpend('a', 6, T0 + HOUR);
  limiter.recordSpend('a', 6, T0 + 2 * HOUR);
  const now = T0 + 3 * HOUR;
  // $18 against a $15 cap: dropping the first $6 (at T0) brings it to $12.
  assert.deepEqual(checkSpendCap(limiter, 'a', now), { over: true, retryAfterSeconds: 21 * 3600 });
  // Against a $10 cap, two entries must age out ($18 → $12 → $6): the wait runs to the second.
  assert.equal(limiter.spendRetryAfterSeconds('a', now, 10), 22 * 3600);
  assert.equal(limiter.spendRetryAfterSeconds('a', now, 100), 0, 'under the cap: no wait');
  assert.deepEqual(checkSpendCap(limiter, 'a', T0 + 24 * HOUR + 1), { over: false }, 'after the first ages out');
});

// A clock stepping back (NTP) must not break the oldest-first order the windows rely on.
test('a clock that goes backwards never lets extra requests through', () => {
  const limiter = new MemoryLimiter();
  const max = DOOR_LIMITS.buckets.write[0]!.max;
  for (let i = 0; i < max - 1; i++) assert.equal(limiter.take('a', 'write', T0 + 30_000).ok, true);
  assert.equal(limiter.take('a', 'write', T0).ok, true, 'one more, 30 s in the past');
  assert.equal(limiter.take('a', 'write', T0 + 30_001).ok, false, 'the window is full');
  assert.equal(limiter.take('a', 'write', T0 + 30_000 + MINUTE - 1).ok, false, 'still full: the stepped-back one counts as recorded at the later time');
  assert.equal(limiter.take('a', 'write', T0 + 30_000 + MINUTE).ok, true);

  limiter.recordSpend('b', 10, T0 + HOUR);
  limiter.recordSpend('b', 10, T0);
  assert.equal(limiter.spentToday('b', T0 + HOUR + 24 * HOUR - 1), 20, 'both still counted until the later time ages out');
  assert.equal(limiter.spentToday('b', T0 + HOUR + 24 * HOUR), 0);
});

test('spend records idle for 24 hours are forgotten too', () => {
  const limiter = new MemoryLimiter();
  limiter.recordSpend('a', 1, T0);
  limiter.recordSpend('b', 1, T0 + 23 * HOUR);
  assert.equal(limiter.spendSize(), 2);
  limiter.take('c', 'read', T0 + 25 * HOUR);
  assert.equal(limiter.spendSize(), 1, 'a is gone; b spent within the last 24 hours');
});
