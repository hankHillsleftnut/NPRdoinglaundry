import { Router, type Request, type Response } from 'express';
import { z } from 'zod';

import { displayCode, inviteLink, mintCodes } from './codes.js';

import type { InviteStore } from './store.js';

/**
 * The founder's invite tools (BE0.12), behind the admin secret:
 *   GET  /admin/waitlist?status=            who is waiting (or approved, declined)
 *   POST /admin/waitlist/:id/approve        a founder invite for them; its code and link, once
 *   POST /admin/waitlist/:id/decline
 *   POST /admin/invites { count, kind, expiresAt? }   founder or review codes and links, once
 *   GET  /admin/invites                     who invited whom, used or not; never a code
 *   POST /admin/invites/:id/revoke          an unused invite stops working
 *   POST /admin/users/:id/invites { add }   more invites for a person
 *   POST /admin/users/:id/suspend           pause a person (their doors answer `suspended`)
 * A plain code exists only in the one response that made it. Errors are
 * generic; the detail is logged by error name only.
 */
export interface AdminInviteDeps {
  invites: InviteStore;
  now: () => number;
  codeKey: string | null;
  baseUrl: string;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const CreateBody = z.object({
  count: z.number().int().min(1).max(50),
  kind: z.enum(['founder', 'review']),
  expiresAt: z.string().datetime().nullable().optional(),
}).strict();
const AddBody = z.object({ add: z.number().int().min(1).max(20) }).strict();

export function createAdminInviteRouter(deps: AdminInviteDeps): Router {
  const router = Router();
  const iso = () => new Date(deps.now()).toISOString();
  const shown = (code: string) => ({ code: displayCode(code), link: inviteLink(deps.baseUrl, code) });
  const failed = (res: Response, err: unknown) => {
    console.error(`[admin] invites failed (${err instanceof Error ? err.name : 'unknown'})`);
    res.status(500).json({ success: false, error: 'Invite action failed' });
  };
  const bad = (res: Response, error: string) => res.status(400).json({ success: false, error });
  const needKey = (res: Response): string | null => {
    if (deps.codeKey) return deps.codeKey;
    res.status(503).json({ success: false, error: 'INVITE_CODE_KEY is not set, so no invite can be made' });
    return null;
  };
  const id = (req: Request) => String(req.params.id ?? '');

  router.get('/waitlist', async (req, res) => {
    const status = typeof req.query.status === 'string' ? req.query.status : null;
    if (status !== null && !['waiting', 'approved', 'declined'].includes(status)) return void bad(res, 'status is waiting, approved or declined');
    try {
      res.json({ success: true, data: await deps.invites.waitlist(status as 'waiting' | 'approved' | 'declined' | null) });
    } catch (err) { failed(res, err); }
  });

  router.post('/waitlist/:id/approve', async (req, res) => {
    if (!UUID.test(id(req))) return void bad(res, 'id must be a UUID');
    const key = needKey(res);
    if (!key) return;
    try {
      const minted = mintCodes(1, key);
      const ok = await deps.invites.approve(id(req), minted.hashes[0]!, minted.sealed[0]!, iso());
      if (!ok) return void res.status(409).json({ success: false, error: 'That person is not waiting' });
      res.json({ success: true, data: shown(minted.codes[0]!) });
    } catch (err) { failed(res, err); }
  });

  router.post('/waitlist/:id/decline', async (req, res) => {
    if (!UUID.test(id(req))) return void bad(res, 'id must be a UUID');
    try {
      const ok = await deps.invites.decline(id(req), iso());
      if (!ok) return void res.status(409).json({ success: false, error: 'That person is not waiting' });
      res.json({ success: true, data: { declined: true } });
    } catch (err) { failed(res, err); }
  });

  router.post('/invites', async (req, res) => {
    const body = CreateBody.safeParse(req.body ?? {});
    if (!body.success) return void bad(res, 'count 1-50, kind founder or review, expiresAt optional');
    const key = needKey(res);
    if (!key) return;
    try {
      const minted = mintCodes(body.data.count, key);
      await deps.invites.create({
        kind: body.data.kind, ownerUserId: null, hashes: minted.hashes, sealed: minted.sealed, expiresAt: body.data.expiresAt ?? null, nowIso: iso(),
      });
      res.json({ success: true, data: { invites: minted.codes.map(shown) } });
    } catch (err) { failed(res, err); }
  });

  router.get('/invites', async (_req, res) => {
    try {
      res.json({ success: true, data: await deps.invites.all() });
    } catch (err) { failed(res, err); }
  });

  router.post('/invites/:id/revoke', async (req, res) => {
    if (!UUID.test(id(req))) return void bad(res, 'id must be a UUID');
    try {
      const ok = await deps.invites.revoke(id(req), iso());
      if (!ok) return void res.status(409).json({ success: false, error: 'That invite is used, revoked or unknown' });
      res.json({ success: true, data: { revoked: true } });
    } catch (err) { failed(res, err); }
  });

  router.post('/users/:id/invites', async (req, res) => {
    if (!UUID.test(id(req))) return void bad(res, 'id must be a UUID');
    const body = AddBody.safeParse(req.body ?? {});
    if (!body.success) return void bad(res, 'add 1-20');
    const key = needKey(res);
    if (!key) return;
    try {
      const minted = mintCodes(body.data.add, key);
      const ids = await deps.invites.create({
        kind: 'member', ownerUserId: id(req), hashes: minted.hashes, sealed: minted.sealed, expiresAt: null, nowIso: iso(),
      });
      // The person sees these in "your invites"; nothing is shown here.
      res.json({ success: true, data: { added: ids.length } });
    } catch (err) { failed(res, err); }
  });

  router.post('/users/:id/suspend', async (req, res) => {
    if (!UUID.test(id(req))) return void bad(res, 'id must be a UUID');
    try {
      const ok = await deps.invites.setAccess(id(req), 'suspended');
      if (!ok) return void res.status(404).json({ success: false, error: 'No such user' });
      res.json({ success: true, data: { access: 'suspended' } });
    } catch (err) { failed(res, err); }
  });

  return router;
}

