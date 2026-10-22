import { config } from '../utils/config.js';
import { DoorError, SPEND_RETRY_FALLBACK_SECONDS } from '../doors/errors.js';

interface AgentIngestResponse {
  traceId: string | null;
  observations_created: number;
  insights_created: number;
  goal_candidates_created: number;
  raw_content_processed: number;
  processingNotes?: string;
}

interface AgentPodcastResponse {
  traceId: string | null;
  episodeId: string | null;
  title: string;
  description: string;
  mood: string;
  durationSeconds: number;
  audioUrl: string | null;
}

interface AgentIntegrationResponse {
  syncRunId: string;
  ingestionTraceId: string | null;
  itemsSeen: number;
  itemsCreated: number;
  itemsUpdated: number;
  itemsSkipped: number;
  itemsFailed: number;
  rawContentIds: string[];
  failures: { providerObjectId: string; error: string }[];
}

// Default below the iOS client's request timeout (480s) so the BACKEND fails
// first with a clean error instead of the phone silently bailing on a still-
// running, goal-writing request (which produced "Couldn't read your goals" on
// a pipeline that actually succeeded server-side).
const AGENT_TIMEOUT_MS = 450_000;
export const AGENT_MAX_ATTEMPTS = 3;

/**
 * The agent refused for spend (BEA.4): the person's daily cap, or in staging
 * the project's. Never retried: the money is gone until the window rolls, and
 * a retry would only burn the attempt budget. Carries the agent's numbers and
 * the wait, and maps to contract 00's `spend_limited` (BE0.11).
 */
export class AgentSpendLimitedError extends Error {
  readonly code = 'spend_limited' as const;
  readonly status = 429;
  constructor(
    readonly path: string,
    readonly retryAfterSeconds: number,
    readonly spentUsd: number | null,
    readonly capUsd: number | null,
    readonly scope: 'person' | 'project',
  ) {
    super(`Agent refused for spend (${path}): ${scope} cap`);
    this.name = 'AgentSpendLimitedError';
  }

  toDoorError(): DoorError {
    return new DoorError('spend_limited', { retryAfterSeconds: this.retryAfterSeconds });
  }
}

export function isAgentSpendLimited(err: unknown): err is AgentSpendLimitedError {
  return err instanceof AgentSpendLimitedError;
}

/** The `Retry-After` header as whole seconds, when it is one; else the honest upper bound of the agent's window. */
function spendRetryAfter(header: string | null): number {
  const n = Number(header);
  return Number.isInteger(n) && n > 0 ? n : SPEND_RETRY_FALLBACK_SECONDS;
}

export interface AgentCallerDeps {
  fetch: typeof fetch;
  /** Waits between retries; tests pass a no-op. */
  sleep: (ms: number) => Promise<void>;
}

const realDeps: AgentCallerDeps = {
  fetch: (...args) => fetch(...args),
  sleep: (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
};

/** The old routes' agent client. `createAgentCaller` exists so its retry rules are tested without a network. */
export function createAgentCaller(deps: AgentCallerDeps = realDeps) {
  return async function callAgent<T>(
    path: string,
    body: Record<string, unknown>,
    timeoutMs = AGENT_TIMEOUT_MS,
    method: 'POST' | 'PUT' = 'POST'
  ): Promise<T> {
    const baseUrl = config.agent.serviceUrl.replace(/\/+$/, '');
    const url = `${baseUrl}${path}`;
    const startedAt = Date.now();

    for (let attempt = 1; attempt <= AGENT_MAX_ATTEMPTS; attempt++) {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), timeoutMs);

      try {
        const response = await deps.fetch(url, {
          method,
          headers: {
            'Content-Type': 'application/json',
            'X-Internal-Secret': config.agent.internalSecret,
          },
          body: JSON.stringify(body),
          signal: controller.signal,
        });

        const text = await response.text();
        clearTimeout(timeout); // response fully read; disarm so it can't abort during a retry sleep

        // Parse only if the body is actually JSON. A non-JSON body (e.g. a plain
        // "Too Many Requests" from the edge) used to blow up JSON.parse with a
        // cryptic "Unexpected token 'T'"; surface the real status + snippet instead.
        let payload: unknown = {};
        let parseFailure: string | null = null;
        if (text) {
          try {
            payload = JSON.parse(text);
          } catch {
            parseFailure = text.slice(0, 200).replace(/\s+/g, ' ').trim();
          }
        }

        if (response.status === 429) {
          // The agent's spend refusal (BEA.4) is never retried: the cap holds until the window rolls.
          const refusal = payload && typeof payload === 'object' ? (payload as Record<string, unknown>) : {};
          if (refusal.error === 'spend_limited') {
            const num = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? v : null);
            console.warn(`[agent] ${path} -> 429 spend_limited (${refusal.scope === 'project' ? 'project' : 'person'}); not retried`);
            throw new AgentSpendLimitedError(
              path, spendRetryAfter(response.headers.get('retry-after')), num(refusal.spentUsd), num(refusal.capUsd),
              refusal.scope === 'project' ? 'project' : 'person',
            );
          }
          // Any other 429 is rejected at the edge (Cloudflare/Render) BEFORE the
          // pipeline runs, so re-sending is safe. We must NEVER retry 5xx/timeouts:
          // /ingest/run is a long, side-effectful, non-idempotent operation and a
          // blind retry would double-run Cook 0.
          if (attempt < AGENT_MAX_ATTEMPTS) {
            const retryAfter = Number(response.headers.get('retry-after'));
            const delayMs =
              Number.isFinite(retryAfter) && retryAfter > 0 ? retryAfter * 1000 : attempt * 2000;
            console.warn(
              `[agent] ${path} -> 429 (attempt ${attempt}/${AGENT_MAX_ATTEMPTS}); retrying in ${delayMs}ms`
            );
            await deps.sleep(delayMs);
            continue;
          }
        }

        if (parseFailure !== null) {
          throw new Error(
            `Agent request failed (${path}): HTTP ${response.status} — non-JSON response: "${parseFailure}"`
          );
        }

        if (!response.ok) {
          const message =
            payload && typeof payload === 'object' && 'error' in payload
              ? String((payload as { error: unknown }).error)
              : `HTTP ${response.status}`;
          throw new Error(`Agent request failed (${path}): ${message}`);
        }

        console.log(`[agent] ${path} -> ok in ${Date.now() - startedAt}ms (attempt ${attempt})`);
        return payload as T;
      } catch (error) {
        if (error instanceof Error && error.name === 'AbortError') {
          throw new Error(`Agent request timed out (${path}) after ${timeoutMs}ms`);
        }
        throw error;
      } finally {
        clearTimeout(timeout);
      }
    }

    // Exhausted all attempts on 429.
    throw new Error(
      `Agent request failed (${path}): rate limited (429) after ${AGENT_MAX_ATTEMPTS} attempts`
    );
  };
}

const callAgent = createAgentCaller();

export function runAgentIngest(options: {
  userId: string;
  rawContentIds?: string[];
  daysBack?: number;
  notes?: string;
}): Promise<AgentIngestResponse> {
  return callAgent<AgentIngestResponse>('/ingest/run', {
    userId: options.userId,
    rawContentIds: options.rawContentIds,
    daysBack: options.daysBack ?? 1,
    notes: options.notes ?? 'Triggered by retrospect-api /content upload',
  });
}

export interface AgentStatedGoal {
  title: string;
  description: string;
  reasoning: string;
  quote: string;
}

/** The goals stated in onboarding answers, each resting on a verified quote. Seconds. */
export function getAgentOnboardingGoals(
  userId: string,
  answersText: string,
): Promise<{ goals: AgentStatedGoal[]; dropped: number }> {
  return callAgent<{ goals: AgentStatedGoal[]; dropped: number }>('/onboarding/goals', { userId, answersText }, 90_000);
}

export function generateAgentPodcast(options: {
  userId: string;
  daysBack?: number;
  skipTTS?: boolean;
  persona?: string;
  notes?: string;
}): Promise<AgentPodcastResponse> {
  return callAgent<AgentPodcastResponse>('/podcasts/generate', {
    userId: options.userId,
    daysBack: options.daysBack ?? 14,
    skipTTS: options.skipTTS ?? false,
    persona: options.persona,
    notes: options.notes ?? 'Triggered by retrospect-api /podcasts/generate',
  });
}

/** Goal 20: a correction goes through the agent, so it propagates and never comes back. */
export function applyAgentCorrection(body: { userId: string; kind: 'fact'; id: string; note?: string | null; mode: 'wrong' | 'changed' }): Promise<{ outcome: string; retired: number }> {
  return callAgent<{ outcome: string; retired: number }>('/corrections/confirm', body, 30_000);
}

export function processAgentIntegrationBatch(body: Record<string, unknown>): Promise<AgentIntegrationResponse> {
  return callAgent<AgentIntegrationResponse>('/integrations/process', body);
}

interface AgentQueuedJobResponse {
  jobId: string;
  status: string;
}

export function enqueueAgentIntegrationBatch(body: Record<string, unknown>): Promise<AgentQueuedJobResponse> {
  return callAgent<AgentQueuedJobResponse>('/integrations/enqueue-device-batch', body, 30_000);
}

export function queueAgentIntegrationImport(body: Record<string, unknown>): Promise<AgentQueuedJobResponse> {
  return callAgent<AgentQueuedJobResponse>('/integrations/queue-import', body, 30_000);
}

export function requestAgentIntegrationSync(connectionId: string, userId: string): Promise<AgentQueuedJobResponse> {
  return callAgent<AgentQueuedJobResponse>(`/integrations/connections/${connectionId}/sync`, { userId }, 30_000);
}

export function requestAgentIntegrationDataDeletion(connectionId: string, userId: string): Promise<AgentQueuedJobResponse> {
  return callAgent<AgentQueuedJobResponse>(`/integrations/connections/${connectionId}/delete-data`, { userId }, 30_000);
}

export function storeAgentIntegrationCredentials(
  connectionId: string,
  body: Record<string, unknown>
): Promise<void> {
  return callAgent<void>(`/integrations/connections/${connectionId}/credentials`, body, 30_000, 'PUT');
}
