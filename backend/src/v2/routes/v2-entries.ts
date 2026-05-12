/**
 * v2 entry-analysis routes — plain single Claude calls behind authenticated
 * endpoints so the iOS app never has to ship Anthropic / OpenAI keys.
 *
 *   POST /v2/entries/analyze-metadata  — title + tags from journal text
 *   POST /v2/entries/analyze-images    — Claude vision over base64 images
 *
 * These are NOT agents. Per the Apr 12 architecture meeting, only Stage 2 of
 * the podcast pipeline runs as an agent; everything else is a plain LLM call.
 */

import { Router, Request, Response } from 'express';
import { z } from 'zod';
import Anthropic from '@anthropic-ai/sdk';
import { config } from '../../utils/config.js';
import { jsonChatCompletion } from '../../utils/openai.js';
import { ENTRY_METADATA_SYSTEM, IMAGE_ANALYSIS_SYSTEM } from '../podcast/prompts.js';

export const v2EntriesRouter = Router();

const anthropic = new Anthropic({ apiKey: config.anthropic.apiKey });

// ============================================
// POST /v2/entries/analyze-metadata
// ============================================

const MetadataBodySchema = z.object({
  content: z.string().min(1).max(20000),
});

const MetadataOutputSchema = z.object({
  title: z.string().min(1).max(120),
  tags: z.array(z.string().min(1).max(40)).max(8).default([]),
});

v2EntriesRouter.post('/analyze-metadata', async (req: Request, res: Response) => {
  try {
    if (!req.user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const parsed = MetadataBodySchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({
        success: false,
        error: 'Invalid body',
        details: parsed.error.errors,
      });
      return;
    }

    const raw = await jsonChatCompletion<unknown>(ENTRY_METADATA_SYSTEM, parsed.data.content, {
      temperature: 0.3,
      maxTokens: 300,
    });

    const out = MetadataOutputSchema.safeParse(raw);
    if (!out.success) {
      console.error('[v2:entries] metadata schema validation failed:', out.error.issues);
      res.status(502).json({
        success: false,
        error: 'Model returned malformed metadata',
      });
      return;
    }

    res.json({ success: true, data: out.data });
  } catch (err) {
    console.error('[v2:entries] analyze-metadata failed:', err);
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'analyze-metadata failed',
    });
  }
});

// ============================================
// POST /v2/entries/analyze-images
// ============================================

const ImageInputSchema = z.object({
  // Base64-encoded image data (the iOS app already encodes JPEGs this way)
  mediaType: z.enum(['image/jpeg', 'image/png', 'image/webp', 'image/gif']).default('image/jpeg'),
  data: z.string().min(1),
});

const ImagesBodySchema = z.object({
  images: z.array(ImageInputSchema).min(1).max(5),
  // Optional surrounding journal text to anchor the vision analysis
  context: z.string().max(20000).optional(),
});

const ImageDescriptionSchema = z.object({
  description: z.string(),
  mood: z.string().optional().default(''),
  significance: z.string().optional().default(''),
});

const ImagesOutputSchema = z.object({
  images: z.array(ImageDescriptionSchema).default([]),
  combinedContext: z.string().default(''),
});

v2EntriesRouter.post('/analyze-images', async (req: Request, res: Response) => {
  try {
    if (!req.user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const parsed = ImagesBodySchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({
        success: false,
        error: 'Invalid body',
        details: parsed.error.errors,
      });
      return;
    }

    const { images, context: userContext } = parsed.data;

    const userBlocks: Anthropic.Messages.ContentBlockParam[] = images.map((img) => ({
      type: 'image' as const,
      source: {
        type: 'base64' as const,
        media_type: img.mediaType,
        data: img.data,
      },
    }));

    userBlocks.push({
      type: 'text',
      text: userContext
        ? `Journal context (for grounding only — do not echo back):\n${userContext}\n\nAnalyze the attached image(s) per the system prompt and return the JSON object.`
        : 'Analyze the attached image(s) per the system prompt and return the JSON object.',
    });

    const response = await anthropic.messages.create({
      model: config.anthropic.model,
      system: `${IMAGE_ANALYSIS_SYSTEM}\n\nIMPORTANT: respond with valid JSON only. No markdown fences, no prose around it.`,
      messages: [{ role: 'user', content: userBlocks }],
      temperature: 0.4,
      max_tokens: 1500,
    });

    const textBlock = response.content.find((b) => b.type === 'text');
    if (!textBlock || textBlock.type !== 'text') {
      throw new Error('No text response from Claude vision');
    }

    let cleaned = textBlock.text.trim();
    if (cleaned.startsWith('```json')) cleaned = cleaned.slice(7);
    else if (cleaned.startsWith('```')) cleaned = cleaned.slice(3);
    if (cleaned.endsWith('```')) cleaned = cleaned.slice(0, -3);
    cleaned = cleaned.trim();

    let rawJson: unknown;
    try {
      rawJson = JSON.parse(cleaned);
    } catch {
      console.error('[v2:entries] image JSON parse failed:', cleaned.slice(0, 200));
      res.status(502).json({ success: false, error: 'Model returned malformed JSON' });
      return;
    }

    const out = ImagesOutputSchema.safeParse(rawJson);
    if (!out.success) {
      console.error('[v2:entries] image schema validation failed:', out.error.issues);
      res.status(502).json({
        success: false,
        error: 'Model returned malformed image analysis',
      });
      return;
    }

    res.json({ success: true, data: out.data });
  } catch (err) {
    console.error('[v2:entries] analyze-images failed:', err);
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'analyze-images failed',
    });
  }
});
