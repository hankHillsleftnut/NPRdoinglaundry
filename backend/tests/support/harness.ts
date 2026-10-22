/**
 * The HTTP test harness (testing.md layer 3): the real app from createApp on a
 * free port, with
 *   - an in-memory user table (signed tokens come from `asUser`),
 *   - a scripted fake agent: a local HTTP server whose handlers each test sets,
 *     reached through the real door agent client,
 *   - a fresh limiter and a clock the test controls,
 *   - the door log captured instead of written.
 * Nothing touches the network beyond 127.0.0.1, and nothing needs a real key
 * (tests/support/env.ts sets placeholders).
 */
import { createServer, type IncomingMessage, type Server, type ServerResponse } from 'node:http';
import type { AddressInfo } from 'node:net';
import { createApp, type AppDeps } from '../../src/app.js';
import { createAgentDoorClient } from '../../src/doors/agent.js';
import { MemoryLimiter } from '../../src/doors/limits.js';
import { createDiagnosticsStore } from '../../src/diagnostics/store.js';
import { memoryDiagnostics } from './memory-diagnostics.js';
import jwt from 'jsonwebtoken';
import type { AuthUser } from '../../src/types/index.js';
import { createLog } from '../../src/utils/log.js';

export type AgentReply = { status: number; body?: unknown } | 'hang';
/** Handlers keyed `METHOD /path` (path without the query). */
export type AgentRoutes = Record<string, (body: unknown, url: URL) => AgentReply | Promise<AgentReply>>;

export interface Harness {
  url: string;
  /** Adds the user if needed and returns an access token for them, issued at the harness clock (valid 30 days). */
  asUser(id: string): string;
  request(method: string, path: string, body?: unknown, headers?: Record<string, string>): Promise<{
    status: number; headers: Headers; body: unknown;
  }>;
  /** Replace the fake agent's handlers. */
  setAgent(routes: AgentRoutes): void;
  /** Every request the fake agent received. */
  agentCalls: { method: string; path: string; body: unknown }[];
  clock: { now: number };
  limiter: MemoryLimiter;
  logLines: string[];
  users: Map<string, AuthUser>;
  close(): Promise<void>;
}

async function listen(server: Server): Promise<string> {
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', () => resolve()));
  return `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
}

async function readBody(req: IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];
  for await (const chunk of req) chunks.push(chunk as Buffer);
  const text = Buffer.concat(chunks).toString('utf8');
  if (!text) return undefined;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

/** A store a test didn't set up: any call throws, so a test can't pass by not reaching it. */
function notConfigured<T extends object>(what: string): T {
  return new Proxy({} as T, { get: (_t, prop) => () => Promise.reject(new Error(`harness: ${what}.${String(prop)} is not set up in this test`)) });
}

export async function startHarness(opts: {
  agentRoutes?: AgentRoutes; users?: AuthUser[]; now?: number; v2Router?: AppDeps['v2Router'];
  speechSynth?: AppDeps['speechSynth']; sessions?: AppDeps['sessions'];
  verifyApple?: AppDeps['verifyApple']; accounts?: AppDeps['accounts'];
  diagnostics?: AppDeps['diagnostics'];
  access?: AppDeps['access']; invites?: AppDeps['invites']; entries?: AppDeps['entries'];
  startIngest?: AppDeps['startIngest'];
} = {}): Promise<Harness> {
  let routes: AgentRoutes = opts.agentRoutes ?? {};
  const agentCalls: Harness['agentCalls'] = [];
  const hanging = new Set<ServerResponse>();
  const agentServer = createServer(async (req, res) => {
    const url = new URL(req.url ?? '/', 'http://agent.test');
    const body = await readBody(req);
    agentCalls.push({ method: req.method ?? 'GET', path: url.pathname, body });
    const handler = routes[`${req.method} ${url.pathname}`];
    const reply: AgentReply = handler ? await handler(body, url) : { status: 404, body: { error: 'not found' } };
    if (reply === 'hang') {
      hanging.add(res);
      return;
    }
    res.writeHead(reply.status, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(reply.body ?? {}));
  });
  const agentUrl = await listen(agentServer);

  const users = new Map<string, AuthUser>((opts.users ?? []).map((u) => [u.id, u]));
  const clock = { now: opts.now ?? 1_800_000_000_000 };
  const limiter = new MemoryLimiter();
  const logLines: string[] = [];

  const app = createApp({
    agent: createAgentDoorClient({ baseUrl: agentUrl, internalSecret: process.env.INTERNAL_API_SECRET ?? '' }),
    limiter,
    now: () => clock.now,
    users: async (id) => users.get(id) ?? null,
    log: createLog((line) => logLines.push(line)),
    ...(opts.v2Router ? { v2Router: opts.v2Router } : {}),
    ...(opts.speechSynth ? { speechSynth: opts.speechSynth } : {}),
    diagnostics: opts.diagnostics ?? createDiagnosticsStore(memoryDiagnostics().backend),
    ...(opts.sessions ? { sessions: opts.sessions } : {}),
    ...(opts.verifyApple ? { verifyApple: opts.verifyApple } : {}),
    ...(opts.accounts ? { accounts: opts.accounts } : {}),
    // Tests that use access or invites pass real stores (PGlite); anything else touching them fails loudly.
    access: opts.access ?? notConfigured('access'),
    invites: opts.invites ?? notConfigured('invites'),
    entries: opts.entries ?? notConfigured('entries'),
    ...(opts.startIngest ? { startIngest: opts.startIngest } : {}),
  });
  const appServer = createServer(app);
  const url = await listen(appServer);

  return {
    url,
    asUser(id) {
      if (!users.has(id)) users.set(id, { id, appleUserId: `apple-${id}` });
      const user = users.get(id)!;
      // Same claims as generateToken, but issued at the harness clock, so a test
      // can move the clock past expiry without real time passing.
      return jwt.sign({ userId: user.id, appleUserId: user.appleUserId, iat: Math.floor(clock.now / 1000) }, process.env.JWT_SECRET ?? '', { expiresIn: '30d' });
    },
    async request(method, path, body, headers = {}) {
      const res = await fetch(`${url}${path}`, {
        method,
        headers: { ...(body === undefined ? {} : { 'Content-Type': 'application/json' }), ...headers },
        ...(body === undefined ? {} : { body: typeof body === 'string' ? body : JSON.stringify(body) }),
      });
      const text = await res.text();
      let parsed: unknown = text;
      try {
        parsed = text ? JSON.parse(text) : undefined;
      } catch {
        parsed = text;
      }
      return { status: res.status, headers: res.headers, body: parsed };
    },
    setAgent(next) {
      routes = next;
    },
    agentCalls,
    clock,
    limiter,
    logLines,
    users,
    async close() {
      for (const res of hanging) res.destroy();
      appServer.closeAllConnections();
      agentServer.closeAllConnections();
      await Promise.all([
        new Promise<void>((resolve) => appServer.close(() => resolve())),
        new Promise<void>((resolve) => agentServer.close(() => resolve())),
      ]);
    },
  };
}
