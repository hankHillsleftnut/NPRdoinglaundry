/**
 * Per-user limits for `/v2` doors (backend-engineer.md §4 step 6).
 *
 * Every door names a bucket. A user's requests are counted per bucket in
 * rolling windows, so one user can never use up another's allowance, and the
 * daily model spend is summed over a rolling 24 hours, the same window the
 * agent's own cap uses (agent src/pipelines/spend-guard.ts). Reads are never
 * refused for spend (founder rule); only `expensive` doors check it.
 *
 * Pure and clock-free: every call takes `now` (milliseconds), so tests need no
 * real time. A `now` earlier than the last one recorded (a clock stepping
 * back) is recorded at the last time instead, so every list stays oldest first. In memory, so counts reset when the one Render instance restarts;
 * a shared store replaces MemoryLimiter behind the same interface in BE0.9.
 */

/**
 * `redeem`: invite codes, 5 per 10 minutes per person (a code is 65 bits, but
 * guessing should still be slow). `redeemAddress`: 20 per 10 minutes per
 * address, looser, so a household or a café on one Wi-Fi isn't locked out by
 * one person's typos. `publicWaitlist`: the website's form, 5 an hour per address.
 * `invitePage`: the link page (GET /i/:code), 60 per 10 minutes per address;
 * over it the page is still served, as the neutral page, never a 429, so the
 * only public route that reaches the database can't be used to walk codes.
 * `inviteCheck` / `inviteCheckAddress`: looking at a code before the tear
 * (POST /v2/invites/check), 20 per 10 minutes per person and 60 per address,
 * its own buckets so checking never eats the tear's five.
 */
export type LimitBucket = 'read' | 'write' | 'expensive' | 'redeem' | 'redeemAddress' | 'publicWaitlist' | 'invitePage' | 'inviteCheck' | 'inviteCheckAddress';

export type TakeResult = { ok: true } | { ok: false; retryAfterSeconds: number };

export interface Limiter {
  /** Counts one request in the bucket, or says how long to wait if it is full. */
  take(userId: string, bucket: LimitBucket, now: number): TakeResult;
  /** Adds model spend (dollars) to the user's rolling 24-hour total. */
  recordSpend(userId: string, usd: number, now: number): void;
  /** The user's model spend (dollars) in the 24 hours before `now`. */
  spentToday(userId: string, now: number): number;
  /**
   * Seconds until the user's rolling spend drops back under `capUsd`, as the
   * oldest spend ages out; 0 when already under it. For `spend_limited`'s
   * retryAfterSeconds (contract 00 §2).
   */
  spendRetryAfterSeconds(userId: string, now: number, capUsd: number): number;
}

const MINUTE = 60_000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

export type LimitWindow = { windowMs: number; max: number };

/** Every number the limits use, in one place, so tests and docs read them from here. */
export const DOOR_LIMITS = {
  buckets: {
    read: [{ windowMs: MINUTE, max: 120 }],
    write: [{ windowMs: MINUTE, max: 30 }],
    expensive: [{ windowMs: MINUTE, max: 10 }, { windowMs: HOUR, max: 60 }],
    redeem: [{ windowMs: 10 * MINUTE, max: 5 }],
    redeemAddress: [{ windowMs: 10 * MINUTE, max: 20 }],
    publicWaitlist: [{ windowMs: HOUR, max: 5 }],
    invitePage: [{ windowMs: 10 * MINUTE, max: 60 }],
    inviteCheck: [{ windowMs: 10 * MINUTE, max: 20 }],
    inviteCheckAddress: [{ windowMs: 10 * MINUTE, max: 60 }],
  } satisfies Record<LimitBucket, readonly LimitWindow[]>,
  /** Rolling window for model spend. */
  spendWindowMs: DAY,
  /** Dollars per user per rolling 24 hours; matches the agent's USER_DAILY_SPEND_CAP_USD default. */
  dailySpendCapUsd: 15,
  /** How often idle users are forgotten. */
  sweepEveryMs: HOUR,
} as const;

const longestWindow = (bucket: LimitBucket) => Math.max(...DOOR_LIMITS.buckets[bucket].map((w) => w.windowMs));

export class MemoryLimiter implements Limiter {
  /** Request times per `${bucket}\0${userId}`, oldest first. */
  private readonly hits = new Map<string, number[]>();
  /** Spend per user, oldest first. */
  private readonly spend = new Map<string, { at: number; usd: number }[]>();
  private lastSweep = Number.NEGATIVE_INFINITY;

  take(userId: string, bucket: LimitBucket, now: number): TakeResult {
    this.sweep(now);
    const key = `${bucket}\0${userId}`;
    const times = (this.hits.get(key) ?? []).filter((t) => t > now - longestWindow(bucket));

    let waitMs = 0;
    for (const { windowMs, max } of DOOR_LIMITS.buckets[bucket]) {
      const inWindow = times.filter((t) => t > now - windowMs);
      if (inWindow.length >= max) {
        // The oldest request that keeps the window full has to age out first.
        const freesAt = inWindow[inWindow.length - max]! + windowMs;
        waitMs = Math.max(waitMs, freesAt - now);
      }
    }
    if (waitMs > 0) {
      this.hits.set(key, times);
      return { ok: false, retryAfterSeconds: Math.max(1, Math.ceil(waitMs / 1000)) };
    }
    times.push(Math.max(now, times[times.length - 1] ?? now));
    this.hits.set(key, times);
    return { ok: true };
  }

  recordSpend(userId: string, usd: number, now: number): void {
    if (!(usd > 0)) return;
    const entries = this.recentSpend(userId, now);
    entries.push({ at: Math.max(now, entries[entries.length - 1]?.at ?? now), usd });
    this.spend.set(userId, entries);
  }

  spentToday(userId: string, now: number): number {
    const entries = this.recentSpend(userId, now);
    if (entries.length === 0) this.spend.delete(userId);
    else this.spend.set(userId, entries);
    return entries.reduce((sum, e) => sum + e.usd, 0);
  }

  spendRetryAfterSeconds(userId: string, now: number, capUsd: number): number {
    const entries = this.recentSpend(userId, now);
    let total = entries.reduce((sum, e) => sum + e.usd, 0);
    if (capUsd <= 0 || total < capUsd) return 0;
    for (const e of entries) {
      total -= e.usd;
      if (total < capUsd) {
        return Math.max(1, Math.ceil((e.at + DOOR_LIMITS.spendWindowMs - now) / 1000));
      }
    }
    return Math.max(1, Math.ceil(DOOR_LIMITS.spendWindowMs / 1000));
  }

  /** How many users have request counts tracked; for tests of forgetting. */
  size(): number {
    return new Set([...this.hits.keys()].map((k) => k.split('\0')[1])).size;
  }

  /** How many users have spend tracked; for tests of forgetting. */
  spendSize(): number {
    return this.spend.size;
  }

  private recentSpend(userId: string, now: number): { at: number; usd: number }[] {
    return (this.spend.get(userId) ?? []).filter((e) => e.at > now - DOOR_LIMITS.spendWindowMs);
  }

  /** Forgets users with no request inside their bucket's longest window. */
  private sweep(now: number): void {
    if (now - this.lastSweep < DOOR_LIMITS.sweepEveryMs) return;
    this.lastSweep = now;
    for (const [key, times] of this.hits) {
      const bucket = key.split('\0')[0] as LimitBucket;
      const newest = times[times.length - 1];
      if (newest === undefined || newest <= now - longestWindow(bucket)) this.hits.delete(key);
    }
    for (const [userId, entries] of this.spend) {
      const newest = entries[entries.length - 1];
      if (newest === undefined || newest.at <= now - DOOR_LIMITS.spendWindowMs) this.spend.delete(userId);
    }
  }
}

/**
 * Whether the user's rolling 24-hour spend has reached the cap (expensive doors
 * only), and if so how long until it drops back under it.
 */
export function checkSpendCap(
  limiter: Limiter, userId: string, now: number, capUsd: number = DOOR_LIMITS.dailySpendCapUsd,
): { over: false } | { over: true; retryAfterSeconds: number } {
  if (capUsd <= 0 || limiter.spentToday(userId, now) < capUsd) return { over: false };
  return { over: true, retryAfterSeconds: limiter.spendRetryAfterSeconds(userId, now, capUsd) };
}
