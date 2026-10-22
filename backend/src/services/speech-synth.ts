/**
 * Text to speech through ElevenLabs, bounded.
 *
 * - Text is split at sentence boundaries into chunks under the model's limit.
 * - At most `concurrency` chunks are in flight at once (default 3), so one long
 *   script can't open dozens of provider requests; the audio is joined in the
 *   original order whatever order the chunks finish in.
 * - Each chunk has its own timeout covering the whole exchange, so a hung
 *   provider call ends instead of holding the request open.
 * - A provider failure throws SpeechProviderError with the provider's status
 *   only; what the provider said is kept for the server log, never for the
 *   client.
 */

export interface SynthOptions {
  apiKey: string;
  voiceId: string;
  model: string;
  maxCharsPerRequest: number;
  timeoutMs: number;
  concurrency: number;
  fetch?: typeof fetch;
}

export const SPEECH_DEFAULTS = { timeoutMs: 60_000, concurrency: 3 } as const;

const TTS_URL_BASE = 'https://api.elevenlabs.io/v1/text-to-speech';

export class SpeechProviderError extends Error {
  readonly status: number | null;
  /** For the server log only; never sent to the client. */
  readonly detail: string;
  constructor(status: number | null, detail: string) {
    super(status === null ? 'speech provider unreachable or timed out' : `speech provider answered ${status}`);
    this.name = 'SpeechProviderError';
    this.status = status;
    this.detail = detail;
  }
}

/**
 * Split text at sentence boundaries so no chunk exceeds the model's per-request
 * character limit and no cut lands mid-sentence.
 */
export function chunkScript(text: string, maxChars: number): string[] {
  if (text.length <= maxChars) return [text];

  const chunks: string[] = [];
  let remaining = text;

  while (remaining.length > maxChars) {
    const slice = remaining.slice(0, maxChars);
    const lastBoundary = Math.max(
      slice.lastIndexOf('. '),
      slice.lastIndexOf('! '),
      slice.lastIndexOf('? '),
      slice.lastIndexOf('.\n')
    );

    const cutAt = lastBoundary > 0 ? lastBoundary + 1 : maxChars;
    chunks.push(remaining.slice(0, cutAt).trim());
    remaining = remaining.slice(cutAt).trim();
  }

  if (remaining.length > 0) chunks.push(remaining);
  return chunks;
}

async function synthesizeChunk(text: string, opts: SynthOptions): Promise<Buffer> {
  const doFetch = opts.fetch ?? fetch;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), opts.timeoutMs);
  try {
    const response = await doFetch(`${TTS_URL_BASE}/${opts.voiceId}`, {
      method: 'POST',
      headers: { 'xi-api-key': opts.apiKey, 'Content-Type': 'application/json', Accept: 'audio/mpeg' },
      body: JSON.stringify({
        text,
        model_id: opts.model,
        voice_settings: { stability: 0.5, similarity_boost: 0.75 },
      }),
      signal: controller.signal,
    });
    if (!response.ok) {
      const errorText = await response.text().catch(() => '');
      throw new SpeechProviderError(response.status, errorText.slice(0, 300));
    }
    return Buffer.from(await response.arrayBuffer());
  } catch (err) {
    if (err instanceof SpeechProviderError) throw err;
    throw new SpeechProviderError(null, controller.signal.aborted ? `timed out after ${opts.timeoutMs} ms` : 'network error');
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Runs `work` over `items` with at most `limit` at once; results keep the input
 * order. After the first failure no new item starts (each is a paid call).
 */
export async function mapWithConcurrency<T, R>(items: T[], limit: number, work: (item: T) => Promise<R>): Promise<R[]> {
  const results = new Array<R>(items.length);
  let next = 0;
  let failed = false;
  const worker = async () => {
    while (!failed && next < items.length) {
      const index = next++;
      try {
        results[index] = await work(items[index]!);
      } catch (err) {
        failed = true;
        throw err;
      }
    }
  };
  await Promise.all(Array.from({ length: Math.min(Math.max(1, limit), items.length) }, worker));
  return results;
}

export async function synthesizeSpeech(text: string, opts: SynthOptions): Promise<Buffer> {
  const chunks = chunkScript(text, opts.maxCharsPerRequest);
  const buffers = await mapWithConcurrency(chunks, opts.concurrency, (chunk) => synthesizeChunk(chunk, opts));
  return Buffer.concat(buffers);
}
