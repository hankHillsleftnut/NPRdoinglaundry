import { AgentCallError } from './errors.js';

/**
 * The doors' client for the agent (the brain). The old `callAgent` stays as it
 * is for the old routes.
 *
 * - Every call has an explicit timeout.
 * - Retries are chosen per call: `read` retries once on a timeout, 502, 503 or
 *   504 (safe: reads change nothing); `none` never retries, because a write
 *   without an idempotency key could happen twice (ingest isn't idempotent).
 * - A failure is an AgentCallError carrying only its kind, status and, for a
 *   spend 429, the dollars spent. The agent's message is read and dropped:
 *   it can carry raw Postgres text.
 * - fetch, the URL and the secret are passed in, so it is tested without a
 *   network.
 */
export type RetryPolicy = 'none' | 'read';

export interface AgentCallOptions {
  timeoutMs: number;
  retry: RetryPolicy;
}

export interface AgentDoorClient {
  get<T>(path: string, opts: AgentCallOptions): Promise<T>;
  post<T>(path: string, body: unknown, opts: AgentCallOptions): Promise<T>;
  put<T>(path: string, body: unknown, opts: AgentCallOptions): Promise<T>;
}

export interface AgentClientConfig {
  baseUrl: string;
  internalSecret: string;
  fetch?: typeof fetch;
  /** Starts a call's timeout; returns a cancel. Injected by tests so they use no real clock. */
  setTimer?: (fire: () => void, ms: number) => () => void;
}

const realTimer = (fire: () => void, ms: number) => {
  const t = setTimeout(fire, ms);
  return () => clearTimeout(t);
};

const RETRYABLE_STATUSES: ReadonlySet<number> = new Set([502, 503, 504]);

export function createAgentDoorClient(cfg: AgentClientConfig): AgentDoorClient {
  const doFetch = cfg.fetch ?? fetch;
  const base = cfg.baseUrl.replace(/\/+$/, '');

  async function once<T>(method: string, path: string, body: unknown, timeoutMs: number): Promise<T> {
    const controller = new AbortController();
    const cancelTimer = (cfg.setTimer ?? realTimer)(() => controller.abort(), timeoutMs);
    let response: Response;
    let text: string;
    try {
      // The timeout covers the whole exchange, body included.
      response = await doFetch(`${base}${path}`, {
        method,
        headers: { 'Content-Type': 'application/json', 'X-Internal-Secret': cfg.internalSecret },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
        signal: controller.signal,
      });
      text = await response.text();
    } catch {
      throw new AgentCallError({ kind: controller.signal.aborted ? 'timeout' : 'network' });
    } finally {
      cancelTimer();
    }

    let payload: unknown;
    try {
      payload = text ? JSON.parse(text) : {};
    } catch {
      payload = undefined;
    }
    if (!response.ok) {
      const spent = (payload as { spentUsd?: unknown } | undefined)?.spentUsd;
      throw new AgentCallError({
        kind: 'http',
        status: response.status,
        ...(typeof spent === 'number' ? { spentUsd: spent } : {}),
      });
    }
    if (payload === undefined) throw new AgentCallError({ kind: 'http', status: 502 });
    return payload as T;
  }

  async function call<T>(method: string, path: string, body: unknown, opts: AgentCallOptions): Promise<T> {
    try {
      return await once<T>(method, path, body, opts.timeoutMs);
    } catch (err) {
      if (opts.retry === 'read' && err instanceof AgentCallError && isRetryable(err)) {
        return once<T>(method, path, body, opts.timeoutMs);
      }
      throw err;
    }
  }

  return {
    get: (path, opts) => call('GET', path, undefined, opts),
    post: (path, body, opts) => call('POST', path, body, opts),
    put: (path, body, opts) => call('PUT', path, body, opts),
  };
}

function isRetryable(err: AgentCallError): boolean {
  const f = err.failure;
  return f.kind === 'timeout' || (f.kind === 'http' && RETRYABLE_STATUSES.has(f.status));
}
