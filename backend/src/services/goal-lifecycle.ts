/**
 * The lifecycle fields that go with the person switching a goal on or off
 * (goal 7: quitting is respected immediately). Kept in step with is_active so
 * the agent's lifecycle (which reads status) and older readers (is_active)
 * never disagree. Pure.
 */
export function lifecycleFor(isActive: boolean, now = new Date()): Record<string, unknown> {
  return isActive
    ? { is_active: true, status: 'active', merged_into: null, status_reason: 'turned back on by you', status_at: now.toISOString() }
    : { is_active: false, status: 'quit', status_reason: 'turned off by you', status_at: now.toISOString() };
}

/**
 * The current app re-sends its whole goal list after every change and turns
 * "on" any goal the server has off, which undid the brain's merges and expiries
 * (app audit G1). A goal the brain merged or expired comes back only when the
 * person explicitly revives it (`revive: true`), never from an automatic sync.
 * Pure.
 */
export function blocksRevival(currentStatus: string | null | undefined, isActive: boolean | undefined, revive: boolean | undefined): boolean {
  return isActive === true && !revive && (currentStatus === 'merged' || currentStatus === 'expired');
}
