import type { Router } from 'express';
import { z } from 'zod';
import type { DoorFactory } from '../doors/door.js';
import type { AccountDeletion } from './deletion.js';

/**
 * `DELETE /v2/account` (contract 06 §8; BE0.7 + BE6.6a + BE6.6b).
 *
 * Body `{ confirm: "delete", appleAuthorizationCode?: string }`, strict: an
 * unknown field is `invalid_request`. Answers 202
 * `{ deletion: { id, state: "deleting" } }` only once the account is locked
 * (deletion.ts); after that the person's tokens are dead. A waitlisted or a
 * staff-paused (suspended) person may delete too (App Review 5.1.1(v),
 * apple-compliance AC.gate). Rate bucket `write`.
 *
 * The code is never logged or echoed: the door log line has no free text, and
 * the answer carries the deletion id only.
 */
export interface AccountDoorDeps {
  deletion: AccountDeletion;
}

/** Apple's authorization codes are short; this only bounds what is read. */
const MAX_CODE_LENGTH = 1024;

export const AccountDeleteRequest = z.object({
  confirm: z.literal('delete'),
  appleAuthorizationCode: z.string().min(1).max(MAX_CODE_LENGTH).optional(),
}).strict();

export function mountAccountDoors(router: Router, door: DoorFactory, deps: AccountDoorDeps): void {
  router.delete('/account', door({
    name: 'account.delete',
    bucket: 'write',
    openToWaitlisted: true,
    openToSuspended: true,
    request: AccountDeleteRequest,
    call: (ctx, req) => deps.deletion.request({
      userId: ctx.userId,
      ...(req.appleAuthorizationCode !== undefined ? { appleAuthorizationCode: req.appleAuthorizationCode } : {}),
    }),
    map: (r) => ({ deletion: { id: r.id, state: 'deleting' as const } }),
    successStatus: 202,
  }));
}
