import { config } from '../utils/config.js';

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

async function callAgent<T>(
  path: string,
  body: Record<string, unknown>,
  timeoutMs = 600_000
): Promise<T> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const baseUrl = config.agent.serviceUrl.replace(/\/+$/, '');
    const response = await fetch(`${baseUrl}${path}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Internal-Secret': config.agent.internalSecret,
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });

    const text = await response.text();
    const payload = text ? JSON.parse(text) : {};

    if (!response.ok) {
      const message =
        payload && typeof payload === 'object' && 'error' in payload
          ? String(payload.error)
          : `HTTP ${response.status}`;
      throw new Error(`Agent request failed (${path}): ${message}`);
    }

    return payload as T;
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      throw new Error(`Agent request timed out (${path})`);
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

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
