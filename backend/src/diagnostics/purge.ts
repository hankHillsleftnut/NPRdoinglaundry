import type { DiagnosticsStore } from './store.js';

export const PURGE_EVERY_MS = 6 * 60 * 60 * 1000;

/**
 * The 30-day rule, run by the server: once at start, then every six hours.
 * One Render instance, so one purger. A failed run is reported and retried on
 * the next tick; it never stops the server. Returns a stop function.
 */
export function startDiagnosticsPurge(
  store: Pick<DiagnosticsStore, 'purgeExpired'>,
  opts: {
    now: () => number;
    report: (err: unknown) => void;
    every?: (run: () => void, ms: number) => () => void;
  },
): () => void {
  const run = () => {
    store.purgeExpired(opts.now()).then(
      (removed) => { if (removed > 0) console.log(`[diagnostics] removed ${removed} expired reports`); },
      (err: unknown) => opts.report(err),
    );
  };
  const every = opts.every ?? ((fn, ms) => {
    const t = setInterval(fn, ms);
    t.unref();
    return () => clearInterval(t);
  });
  run();
  return every(run, PURGE_EVERY_MS);
}
