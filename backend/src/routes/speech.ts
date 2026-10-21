import { Router, Request, Response } from 'express';
import { config } from '../utils/config.js';

export const speechRouter = Router();

const TTS_URL_BASE = 'https://api.elevenlabs.io/v1/text-to-speech';

// Bounds the spend a single authenticated request can trigger on the provider.
const MAX_TEXT_CHARS = 20_000;

/**
 * Split text at sentence boundaries so no chunk exceeds the model's per-request
 * character limit and no cut lands mid-sentence.
 */
function chunkScript(text: string, maxChars: number): string[] {
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

async function synthesizeChunk(text: string, voiceId: string, apiKey: string): Promise<Buffer> {
  const response = await fetch(`${TTS_URL_BASE}/${voiceId}`, {
    method: 'POST',
    headers: {
      'xi-api-key': apiKey,
      'Content-Type': 'application/json',
      Accept: 'audio/mpeg',
    },
    body: JSON.stringify({
      text,
      model_id: config.elevenlabs.model,
      voice_settings: {
        stability: 0.5,
        similarity_boost: 0.75,
      },
    }),
  });

  if (!response.ok) {
    const errorText = await response.text().catch(() => '');
    throw new Error(`ElevenLabs TTS failed (${response.status}): ${errorText.slice(0, 300)}`);
  }

  return Buffer.from(await response.arrayBuffer());
}

// POST /speech/synthesize
// Body: { text: string }
// Returns: audio/mpeg on success, { success: false, error } otherwise
speechRouter.post('/synthesize', async (req: Request, res: Response): Promise<void> => {
  try {
    const apiKey = config.elevenlabs.apiKey;
    if (!apiKey) {
      res.status(503).json({
        success: false,
        error: 'ELEVENLABS_API_KEY is not configured on the server',
      });
      return;
    }

    const { text } = req.body ?? {};

    if (typeof text !== 'string' || text.trim().length === 0) {
      res.status(400).json({ success: false, error: 'text is required' });
      return;
    }

    if (text.length > MAX_TEXT_CHARS) {
      res.status(400).json({
        success: false,
        error: `text exceeds the ${MAX_TEXT_CHARS} character limit`,
      });
      return;
    }

    const chunks = chunkScript(text, config.elevenlabs.maxCharsPerRequest);
    const buffers = await Promise.all(
      chunks.map((chunk) => synthesizeChunk(chunk, config.elevenlabs.voiceId, apiKey))
    );
    const audio = Buffer.concat(buffers);

    res.setHeader('Content-Type', 'audio/mpeg');
    res.setHeader('Content-Length', String(audio.length));
    res.send(audio);
  } catch (err) {
    console.error('[speech] synthesis error:', err);
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'Speech synthesis failed',
    });
  }
});
