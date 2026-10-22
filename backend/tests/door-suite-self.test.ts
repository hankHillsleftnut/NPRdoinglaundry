import { Router } from 'express';
import { z } from 'zod';
import { createV2Router } from '../src/doors/router.js';
import type { DoorFactory } from '../src/doors/door.js';
import { doorSuite } from './support/door-suite.js';

/**
 * The suite proving itself: /v2/ping calls no agent and names no thing, so it
 * skips four of the nine. This sample door does both (it is mounted only here),
 * so all eight live tests run through the real app, the real agent client and
 * the fake agent.
 */
const owners = new Map<string, string>();
function withSampleDoor(door: DoorFactory): Router {
  const router = createV2Router(door);
  router.get('/samples/:id', door({
    name: 'samples.get',
    bucket: 'read',
    request: z.object({ id: z.string().regex(/^s-[a-z0-9]+$/) }).strict(),
    owns: async (ctx, req) => owners.get(req.id) === ctx.userId,
    call: (ctx, req) => ctx.agent.get<{ title: string }>(`/samples/${ctx.userId}/${req.id}`, { timeoutMs: 100, retry: 'read' }),
    map: (r) => ({ title: r.title }),
  }));
  return router;
}

const USER = '11111111-1111-4111-8111-111111111111';
owners.set('s-mine', USER);

doorSuite({
  method: 'GET',
  path: '/v2/samples/s-mine',
  bucket: 'read',
  invalid: { query: 'extra=1' },
  otherUsersThing: (_h, other) => { owners.set('s-theirs', other); return '/v2/samples/s-theirs'; },
  agent: { route: `GET /samples/${USER}/s-mine`, ok: () => ({ status: 200, body: { title: 'a sample', trace_id: 'x' } }) },
  expect: () => ({ title: 'a sample' }),
  v2Router: withSampleDoor,
});
