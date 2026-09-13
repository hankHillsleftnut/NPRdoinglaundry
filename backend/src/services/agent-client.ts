import { config } from '../utils/config.js';
import { getAccountType } from './accounts.js';

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
const AGENT_MAX_ATTEMPTS = 3;

async function callAgent<T>(
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
      const response = await fetch(url, {
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

      // Retry ONLY on 429. A 429 is rejected at the edge (Cloudflare/Render)
      // BEFORE the pipeline runs, so re-sending is safe. We must NEVER retry
      // 5xx/timeouts: /ingest/run is a long, side-effectful, non-idempotent
      // operation and a blind retry would double-run Cook 0.
      if (response.status === 429 && attempt < AGENT_MAX_ATTEMPTS) {
        const retryAfter = Number(response.headers.get('retry-after'));
        const delayMs =
          Number.isFinite(retryAfter) && retryAfter > 0 ? retryAfter * 1000 : attempt * 2000;
        console.warn(
          `[agent] ${path} -> 429 (attempt ${attempt}/${AGENT_MAX_ATTEMPTS}); retrying in ${delayMs}ms`
        );
        await new Promise((resolve) => setTimeout(resolve, delayMs));
        continue;
      }

      // Parse only if the body is actually JSON. A non-JSON body (e.g. a plain
      // "Too Many Requests" from the edge) used to blow up JSON.parse with a
      // cryptic "Unexpected token 'T'"; surface the real status + snippet instead.
      let payload: unknown = {};
      if (text) {
        try {
          payload = JSON.parse(text);
        } catch {
          const snippet = text.slice(0, 200).replace(/\s+/g, ' ').trim();
          throw new Error(
            `Agent request failed (${path}): HTTP ${response.status} — non-JSON response: "${snippet}"`
          );
        }
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
}

export async function runAgentIngest(options: {
  userId: string;
  rawContentIds?: string[];
  daysBack?: number;
  notes?: string;
  /**
   * The flag map resolved for this user on this request (req.featureFlags).
   * Forwarded so the agent service — which owns the actual pipeline behaviour
   * and prompts — can select a variant for ONE user without a deploy. The
   * agent must treat a missing key as false.
   */
  featureFlags?: Readonly<Record<string, boolean>>;
  /** 'real' | 'test'. Lets the agent keep test runs out of its own aggregates. */
  accountType?: string;
}): Promise<AgentIngestResponse> {
  return callAgent<AgentIngestResponse>('/ingest/run', {
    userId: options.userId,
    rawContentIds: options.rawContentIds,
    daysBack: options.daysBack ?? 1,
    notes: options.notes ?? 'Triggered by retrospect-api /content upload',
    featureFlags: options.featureFlags ?? {},
    // Resolve rather than defaulting to 'real': most call sites (all the admin
    // ones, which is exactly how a founder drives a test account) don't pass
    // it, and defaulting to 'real' would tell the agent to count test runs in
    // its own aggregates — the precise thing forwarding this is meant to stop.
    accountType: options.accountType ?? (await getAccountType(options.userId)),
  });
}

export async function generateAgentPodcast(options: {
  userId: string;
  daysBack?: number;
  skipTTS?: boolean;
  persona?: string;
  notes?: string;
  featureFlags?: Readonly<Record<string, boolean>>;
  accountType?: string;
}): Promise<AgentPodcastResponse> {
  return callAgent<AgentPodcastResponse>('/podcasts/generate', {
    userId: options.userId,
    daysBack: options.daysBack ?? 14,
    skipTTS: options.skipTTS ?? false,
    persona: options.persona,
    notes: options.notes ?? 'Triggered by retrospect-api /podcasts/generate',
    featureFlags: options.featureFlags ?? {},
    // Resolve rather than defaulting to 'real': most call sites (all the admin
    // ones, which is exactly how a founder drives a test account) don't pass
    // it, and defaulting to 'real' would tell the agent to count test runs in
    // its own aggregates — the precise thing forwarding this is meant to stop.
    accountType: options.accountType ?? (await getAccountType(options.userId)),
  });
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
