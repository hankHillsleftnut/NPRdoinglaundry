/**
 * The app's version floor (BE0.10, contract 00 §5).
 *
 * A version reads `1.0 (42)`: the marketing version and, in brackets, the
 * build number, which is what the floor compares (builds only go up; the
 * marketing version can stay put across many builds). `GET /v2/meta` tells
 * the app the floor and the newest version; every signed-in door answers
 * `update_required` (426) to a build below the floor. A missing or malformed
 * header is let through until REQUIRE_APP_VERSION is on, because clients
 * before PL1.6 send none.
 *
 * Pure: no clock, no config.
 */
export interface AppVersions {
  /** `MIN_APP_VERSION`, e.g. `1.0 (40)`. */
  minVersion: string;
  /** `LATEST_APP_VERSION`, e.g. `1.1 (55)`; the floor when unset. */
  latestVersion: string;
  /** `REQUIRE_APP_VERSION`: when true a door refuses a request with no usable X-App-Version. */
  requireVersion: boolean;
  /** Where this server runs, for the app's test builds. */
  environment: 'production' | 'staging' | 'local';
}

export interface ParsedVersion {
  version: string;
  build: number;
}

/** `1.0 (42)` → { version: '1.0', build: 42 }; a dotted build (`42.1`) compares by its first number. Null for anything else. */
export function parseAppVersion(value: string | undefined | null): ParsedVersion | null {
  if (typeof value !== 'string') return null;
  const m = /^(\d{1,4}(?:\.\d{1,4}){0,2}) \((\d{1,8})(?:\.\d{1,8}){0,2}\)$/.exec(value);
  if (!m) return null;
  return { version: m[1]!, build: Number(m[2]) };
}

export type VersionVerdict = 'ok' | 'update_required';

/**
 * Whether a request's X-App-Version may pass the floor. `minBuild` is the
 * floor's build number; a header that isn't a version counts as missing.
 */
export function checkAppVersion(header: string | undefined, minBuild: number, requireVersion: boolean): VersionVerdict {
  const parsed = parseAppVersion(header);
  if (parsed === null) return requireVersion ? 'update_required' : 'ok';
  return parsed.build < minBuild ? 'update_required' : 'ok';
}

/** The floor's build number, or a thrown error: a server with an unreadable floor must not start. */
export function minBuildOf(versions: Pick<AppVersions, 'minVersion'>): number {
  const parsed = parseAppVersion(versions.minVersion);
  if (parsed === null) throw new Error('MIN_APP_VERSION must read like "1.0 (40)"');
  return parsed.build;
}

/** `production | staging | local` from RETROSPECT_ENV and NODE_ENV; anything else is local. */
export function environmentOf(retrospectEnv: string | undefined, nodeEnv: string | undefined): AppVersions['environment'] {
  if (retrospectEnv === 'production' || retrospectEnv === 'staging') return retrospectEnv;
  if (retrospectEnv === undefined || retrospectEnv === '') return nodeEnv === 'production' ? 'production' : 'local';
  return 'local';
}
