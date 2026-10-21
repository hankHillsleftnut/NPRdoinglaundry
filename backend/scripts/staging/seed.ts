/**
 * Local staging's test accounts (testing.md T08), and what each one holds.
 *
 *   fresh    nothing: a brand new account
 *   day-one  the onboarding answers only
 *   month    30 days of typed and voice entries, one brief, two guesses, one episode
 *
 * Every word here is invented for testing; nothing comes from a real person.
 * Rows are marked as seeded -- `metadata.test_account = true` where the table
 * has metadata (raw_content, podcast_episodes), `model_version = 'staging-seed'`
 * where it has not (daily_briefs, hypotheses) -- so a re-run finds them.
 *
 * Re-running is safe: the account is found again through the keyed dev route,
 * and a table that already holds the account's seeded rows is left alone. Each
 * table's rows go in as one insert, so a table is never half-seeded. The brief
 * is the exception: "today's brief" is checked by date, so a re-run on a later
 * day adds that day's brief (and never clashes with a brief the agent wrote).
 *
 * Before anything is written, a database holding any real user is refused.
 *
 * The database sits behind SeedPorts, so this is tested with a fake.
 */

export const ACCOUNTS = ['fresh', 'day-one', 'month'] as const;
export type AccountKey = (typeof ACCOUNTS)[number];

export const SEED_MODEL_VERSION = 'staging-seed';
export const MONTH_DAYS = 30;

export type SeedTable = 'raw_content' | 'daily_briefs' | 'hypotheses' | 'podcast_episodes';
export type Row = Record<string, unknown>;

export interface SeedPorts {
  /** Finds or creates the account through `POST /auth/dev/test-user { key }`; returns its id. */
  ensureAccount(key: AccountKey): Promise<string>;
  /** Ids of the account's seeded rows in a table, oldest first. */
  seededIds(table: SeedTable, userId: string): Promise<string[]>;
  /** Inserts rows in one statement; returns their ids in the same order. */
  insert(table: SeedTable, rows: Row[]): Promise<string[]>;
  /** Removes the account and, by cascade, everything it holds. */
  deleteAccount(userId: string): Promise<void>;
  /** Whether the account has any brief (seeded or not) for this date: one per day is unique. */
  hasBriefOn(userId: string, briefDate: string): Promise<boolean>;
  /** Users who are not dev-test-user accounts. Anything above zero means this isn't staging. */
  nonTestUserCount(): Promise<number>;
}

export class NotStagingDatabaseError extends Error {
  constructor(n: number) {
    super(`Refusing to seed: this database has ${n} users who are not test accounts, so it is not staging.`);
    this.name = 'NotStagingDatabaseError';
  }
}

export type SeedReport = { account: AccountKey; userId: string; inserted: Partial<Record<SeedTable, number>> };

const DAY_MS = 24 * 60 * 60 * 1000;

const ENTRY_LINES = [
  'slow morning, coffee by the window, then a long walk before work',
  'the planning meeting ran long; I want shorter meetings this week',
  'cooked dinner for friends and stayed up talking about travel plans',
  'skipped the walk today and felt it by the afternoon',
  'finished the chapter I have been stuck on for a week',
  'a quiet day; read in the park and called home',
];

const ONBOARDING_ANSWERS = [
  'Test onboarding answers (invented).',
  'What I want more of: early walks and fewer late nights.',
  'What I am working on: finishing a long writing project.',
  'People who matter: a sister I call on Sundays, two close friends.',
].join('\n');

/** The month account's entries, oldest first: one a day, alternating typed and voice. */
export function monthEntries(userId: string, now: Date): Row[] {
  return Array.from({ length: MONTH_DAYS }, (_, i) => {
    const daysAgo = MONTH_DAYS - i;
    const voice = i % 2 === 1;
    const day = new Date(now.getTime() - daysAgo * DAY_MS);
    day.setUTCHours(9, 0, 0, 0);
    return {
      user_id: userId,
      content_type: voice ? 'voice_journal' : 'journal_entry',
      content: `Test entry, day ${i + 1}: ${ENTRY_LINES[i % ENTRY_LINES.length]}.`,
      content_date: day.toISOString(),
      processing_status: 'completed',
      metadata: voice ? { test_account: true, duration_seconds: 40 + i } : { test_account: true },
    };
  });
}

function onboardingRows(userId: string, now: Date): Row[] {
  return [{
    user_id: userId,
    content_type: 'onboarding_profile',
    content: ONBOARDING_ANSWERS,
    content_date: now.toISOString(),
    processing_status: 'completed',
    metadata: { test_account: true },
  }];
}

export const briefDate = (now: Date): string => now.toISOString().slice(0, 10);

/** One brief for today (UTC, like the agent's brief_date), quoting the two newest entries. */
export function monthBrief(userId: string, entries: { id: string; content: string }[], now: Date): Row {
  const recent = entries.slice(-2);
  return {
    user_id: userId,
    brief_date: briefDate(now),
    kind: 'brief',
    through_line: 'Test brief: this week kept coming back to early walks and shorter days.',
    items: recent.map((e) => ({
      text: 'Test item: you wrote about this.',
      why: 'it connects to the walks you keep mentioning',
      quote: e.content.split(': ')[1]?.replace(/\.$/, '') ?? e.content,
      sourceRef: { raw_content_id: e.id },
    })),
    dropped: 0,
    model_version: SEED_MODEL_VERSION,
    cost_usd: 0,
  };
}

function monthGuesses(userId: string, now: Date): Row[] {
  const at = now.toISOString();
  return [
    { framework: 'habit_cue', question: 'Test guess: could the morning walks be more about quiet than exercise?' },
    { framework: 'sdt', question: 'Test guess: could the dinners with friends be what makes a week feel good?' },
  ].map((g) => ({
    user_id: userId, ...g,
    rationale: 'Test rationale (invented).',
    supports: [],
    status: 'offered',
    offered_count: 1,
    last_offered_at: at,
    status_at: at,
    model_version: SEED_MODEL_VERSION,
  }));
}

function monthEpisode(userId: string, now: Date): Row {
  return {
    user_id: userId,
    title: 'Test episode 1',
    description: 'A seeded test episode (invented).',
    script: 'Test script. This episode was seeded for local staging and has no real audio.',
    audio_url: null,
    duration_seconds: 300,
    generation_type: 'weekly',
    status: 'ready',
    episode_number: 1,
    covers_period_start: new Date(now.getTime() - 7 * DAY_MS).toISOString(),
    covers_period_end: now.toISOString(),
    metadata: { test_account: true, audio_path: `${userId}/staging-seed-episode-1.mp3` },
  };
}

async function insertIfMissing(
  ports: SeedPorts, table: SeedTable, userId: string, build: () => Row[], report: SeedReport,
): Promise<void> {
  if ((await ports.seededIds(table, userId)).length > 0) return;
  const rows = build();
  if (rows.length === 0) return;
  await ports.insert(table, rows);
  report.inserted[table] = rows.length;
}

export async function seedAccount(key: AccountKey, ports: SeedPorts, now: Date): Promise<SeedReport> {
  const userId = await ports.ensureAccount(key);
  const report: SeedReport = { account: key, userId, inserted: {} };
  if (key === 'day-one') {
    await insertIfMissing(ports, 'raw_content', userId, () => onboardingRows(userId, now), report);
  }
  if (key === 'month') {
    const entries = monthEntries(userId, now);
    let ids = await ports.seededIds('raw_content', userId);
    if (ids.length === 0) {
      ids = await ports.insert('raw_content', entries);
      report.inserted.raw_content = entries.length;
    }
    const withIds = entries.map((e, i) => ({ id: ids[i] ?? '', content: String(e.content) }));
    if (!(await ports.hasBriefOn(userId, briefDate(now)))) {
      await ports.insert('daily_briefs', [monthBrief(userId, withIds, now)]);
      report.inserted.daily_briefs = 1;
    }
    await insertIfMissing(ports, 'hypotheses', userId, () => monthGuesses(userId, now), report);
    await insertIfMissing(ports, 'podcast_episodes', userId, () => [monthEpisode(userId, now)], report);
  }
  return report;
}

/** Seeds every account. With `reset`, each account is removed first and seeded fresh. */
export async function seedAll(ports: SeedPorts, now: Date, opts: { reset: boolean }): Promise<SeedReport[]> {
  const real = await ports.nonTestUserCount();
  if (real > 0) throw new NotStagingDatabaseError(real);
  const reports: SeedReport[] = [];
  for (const key of ACCOUNTS) {
    if (opts.reset) await ports.deleteAccount(await ports.ensureAccount(key));
    reports.push(await seedAccount(key, ports, now));
  }
  return reports;
}
