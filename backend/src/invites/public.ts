import { Router, type Request, type Response } from 'express';
import { z } from 'zod';
import { DoorError, sendError } from '../doors/errors.js';
import type { Limiter } from '../doors/limits.js';
import type { DoorLogLine } from '../utils/log.js';
import { displayCode, hashCode, normaliseCode } from './codes.js';
import type { InviteStore } from './store.js';

/**
 * The public side of invites (BE0.12, contract 00 §4), no token:
 *   POST /public/waitlist                     the website's form; always { received: true }
 *   GET  /i/:code                             the link page (60 per 10 minutes per address; over it, the neutral page)
 *   GET  /.well-known/apple-app-site-association   so /i/* opens the app
 *
 * Nothing here says whether an email is known or a code is valid: the form
 * answers the same either way, and the link page shows the inviter's first
 * name only for a live code, otherwise the same neutral page. No cookies.
 * Never log an email, a code or a link.
 */
export interface PublicInviteDeps {
  invites: InviteStore;
  limiter: Limiter;
  now: () => number;
  log: { door(line: DoorLogLine): void };
  reportBug: (err: unknown, where: string) => void;
  /** Where the page's download button goes; no button when null. */
  appUrl: string | null;
  /** APPLE_TEAM_ID and the app's bundle id; the association file is absent without a team id. */
  teamId: string;
  bundleId: string;
}

const PublicWaitlistBody = z.object({
  email: z.string().email().max(320),
  name: z.string().max(100).nullable().optional(),
  reason: z.string().max(280).nullable().optional(),
  /** A honeypot: people never see it, so anything in it is a bot. */
  website: z.string().max(200).optional(),
}).strict();

const escapeHtml = (s: string) => s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]!));

/** The link page. `from` is set only for a live code; the code is shown as typed into the link, valid or not. */
export function linkPage(opts: { code: string | null; from: string | null; appUrl: string | null }): string {
  const title = opts.from ? `${opts.from} saved you a place on retrospect` : 'a place on retrospect';
  const lines = [
    `<p class="lead">${escapeHtml(title)}.</p>`,
    opts.code ? `<p>download retrospect, then enter this code:</p><p class="code">${escapeHtml(displayCode(opts.code))}</p>` : '<p>download retrospect, then enter the code from your invite.</p>',
    opts.appUrl ? `<p><a class="button" href="${escapeHtml(opts.appUrl)}">download retrospect</a></p>` : '',
  ];
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex"><meta name="referrer" content="no-referrer">
<title>${escapeHtml(title)}</title>
<meta property="og:title" content="${escapeHtml(title)}"><meta property="og:site_name" content="retrospect">
<style>body{font:17px/1.5 -apple-system,system-ui,sans-serif;margin:0;padding:48px 24px;background:#f7f5f0;color:#1c1b19;text-align:center}
.lead{font-size:22px}.code{font:600 22px ui-monospace,monospace;letter-spacing:.08em}
.button{display:inline-block;padding:14px 24px;border-radius:14px;background:#1c1b19;color:#f7f5f0;text-decoration:none}</style>
</head><body>${lines.join('')}</body></html>`;
}

export function createPublicInviteRouter(deps: PublicInviteDeps): Router {
  const router = Router();

  router.post('/public/waitlist', (req: Request, res: Response) => {
    const started = deps.now();
    const done = (status: number, code?: DoorLogLine['code']) =>
      deps.log.door({ door: 'waitlist.public', userId: null, status, ...(code ? { code } : {}), ms: deps.now() - started });
    void (async () => {
      const taken = deps.limiter.take(`ip:${req.ip ?? 'unknown'}`, 'publicWaitlist', started);
      if (!taken.ok) throw new DoorError('rate_limited', { retryAfterSeconds: taken.retryAfterSeconds });
      const parsed = PublicWaitlistBody.safeParse(req.body ?? {});
      if (!parsed.success) throw new DoorError('invalid_request');
      // A bot filled the honeypot: the same answer, nothing stored.
      if (!parsed.data.website) {
        await deps.invites.joinPublicWaitlist({
          email: parsed.data.email, name: parsed.data.name ?? null, reason: parsed.data.reason ?? null, nowIso: new Date(started).toISOString(),
        });
      }
      res.status(200).json({ success: true, data: { received: true } });
      done(200);
    })().catch((err: unknown) => {
      if (!(err instanceof DoorError)) {
        try { deps.reportBug(err, 'waitlist.public'); } catch { /* the client still gets its envelope */ }
      }
      const sent = sendError(res, err);
      done(sent.status, sent.code);
    });
  });

  router.get('/i/:code', (req: Request, res: Response) => {
    const code = normaliseCode(String(req.params.code ?? ''));
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.type('html');
    // Over the address limit the lookup is skipped and the neutral page is
    // served, never a 429: a visitor can't tell "too many" from "not live",
    // and a sweep of codes learns nothing.
    const taken = deps.limiter.take(`ip:${req.ip ?? 'unknown'}`, 'invitePage', deps.now());
    if (!taken.ok) {
      res.status(200).send(linkPage({ code, from: null, appUrl: deps.appUrl }));
      return;
    }
    void (async () => {
      const face = code ? await deps.invites.face(hashCode(code), new Date(deps.now()).toISOString()) : { live: false, from: null };
      res.status(200).send(linkPage({ code, from: face.live ? face.from : null, appUrl: deps.appUrl }));
    })().catch((err: unknown) => {
      try { deps.reportBug(err, 'invites.page'); } catch { /* still answer */ }
      // A lookup failure looks like any other code: the neutral page.
      res.status(200).send(linkPage({ code, from: null, appUrl: deps.appUrl }));
    });
  });

  router.get('/.well-known/apple-app-site-association', (_req: Request, res: Response) => {
    if (!deps.teamId) {
      res.status(404).end();
      return;
    }
    res.type('application/json').send(JSON.stringify({
      applinks: { details: [{ appIDs: [`${deps.teamId}.${deps.bundleId}`], components: [{ '/': '/i/*', comment: 'invite links' }] }] },
    }));
  });

  return router;
}
