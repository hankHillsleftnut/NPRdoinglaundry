import { Router, Request, Response } from 'express';
import { config } from '../utils/config.js';
import { captureException } from '../services/telemetry.js';
import type { Limiter } from '../doors/limits.js';
import { SPEECH_DEFAULTS, SpeechProviderError, synthesizeSpeech, type SynthOptions } from '../services/speech-synth.js';

// Bounds the spend a single authenticated request can trigger on the provider.
const MAX_TEXT_CHARS = 20_000;

export interface SpeechRouteDeps {
  /** Per-user limit, bucket `expensive` (10 a minute, 60 an hour). */
  limiter: Limiter;
  now: () => number;
  synth: Omit<SynthOptions, 'apiKey'> & { apiKey: string | null };
  report?: (err: unknown) => void;
}

/**
 * POST /speech/synthesize. Body: { text: string }. Returns audio/mpeg, or the
 * old routes' `{ success: false, error }` with a generic message: what the
 * provider said goes to the server log and Sentry only.
 */
export function createSpeechRouter(deps: SpeechRouteDeps): Router {
  const router = Router();
  router.post('/synthesize', async (req: Request, res: Response): Promise<void> => {
    try {
      const apiKey = deps.synth.apiKey;
      if (!apiKey) {
        res.status(503).json({ success: false, error: 'ELEVENLABS_API_KEY is not configured on the server' });
        return;
      }

      const { text } = req.body ?? {};
      if (typeof text !== 'string' || text.trim().length === 0) {
        res.status(400).json({ success: false, error: 'text is required' });
        return;
      }
      if (text.length > MAX_TEXT_CHARS) {
        res.status(400).json({ success: false, error: `text exceeds the ${MAX_TEXT_CHARS} character limit` });
        return;
      }

      const userId = req.user?.id;
      if (!userId) {
        res.status(401).json({ success: false, error: 'Unauthorized' });
        return;
      }
      const taken = deps.limiter.take(userId, 'expensive', deps.now());
      if (!taken.ok) {
        res.setHeader('Retry-After', String(taken.retryAfterSeconds));
        res.status(429).json({ success: false, error: 'Too many requests, please try again later' });
        return;
      }

      const audio = await synthesizeSpeech(text, { ...deps.synth, apiKey });
      res.setHeader('Content-Type', 'audio/mpeg');
      res.setHeader('Content-Length', String(audio.length));
      res.send(audio);
    } catch (err) {
      // Status and kind only: the provider's words (which can echo the text) go to Sentry.
      const failure = err instanceof SpeechProviderError ? `${err.kind}, status ${err.status ?? 'none'}` : `unexpected ${err instanceof Error ? err.name : 'error'}`;
      console.error(`[speech] synthesis failed (${failure})`);
      (deps.report ?? captureException)(err);
      res.status(500).json({ success: false, error: 'Speech synthesis failed' });
    }
  });
  return router;
}

/** The ElevenLabs settings from config; the app factory builds the router with the shared limiter. */
export function speechSynthFromConfig(): SpeechRouteDeps['synth'] {
  return {
    apiKey: config.elevenlabs.apiKey || null,
    voiceId: config.elevenlabs.voiceId,
    model: config.elevenlabs.model,
    maxCharsPerRequest: config.elevenlabs.maxCharsPerRequest,
    ...SPEECH_DEFAULTS,
  };
}
