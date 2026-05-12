/**
 * v2 onboarding routes — plain Claude calls for the iMessage-style goals chat.
 *
 *   POST /v2/onboarding/goals-reply    — generate the next assistant message
 *   POST /v2/onboarding/goals-extract  — finalize 2-4 goals from a conversation
 *                                        and insert them into the goals table
 *                                        with embeddings
 *
 * Per the Apr 12 architecture meeting these are NOT agents — single LLM calls.
 */

import { Router, Request, Response } from 'express';
import { z } from 'zod';
import Anthropic from '@anthropic-ai/sdk';
import { config } from '../../utils/config.js';
import { jsonChatCompletion, generateEmbedding } from '../../utils/openai.js';
import { supabaseAdmin, Tables } from '../../utils/supabase.js';
import {
  ONBOARDING_REPLY_SYSTEM,
  ONBOARDING_GOALS_EXTRACT_SYSTEM,
} from '../podcast/prompts.js';

export const v2OnboardingRouter = Router();

const anthropic = new Anthropic({ apiKey: config.anthropic.apiKey });

const MessageSchema = z.object({
  role: z.enum(['user', 'assistant']),
  content: z.string().min(1).max(8000),
});

// ============================================
// POST /v2/onboarding/goals-reply
// ============================================

const ReplyBodySchema = z.object({
  conversation: z.array(MessageSchema).min(1).max(40),
});

v2OnboardingRouter.post('/goals-reply', async (req: Request, res: Response) => {
  try {
    if (!req.user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const parsed = ReplyBodySchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({
        success: false,
        error: 'Invalid body',
        details: parsed.error.errors,
      });
      return;
    }

    const response = await anthropic.messages.create({
      model: config.anthropic.model,
      system: ONBOARDING_REPLY_SYSTEM,
      messages: parsed.data.conversation.map((m) => ({
        role: m.role,
        content: m.content,
      })),
      temperature: 0.7,
      max_tokens: 256,
    });

    const textBlock = response.content.find((b) => b.type === 'text');
    if (!textBlock || textBlock.type !== 'text') {
      throw new Error('No text response from Claude');
    }

    const reply = textBlock.text.trim();
    res.json({ success: true, data: { reply } });
  } catch (err) {
    console.error('[v2:onboarding] goals-reply failed:', err);
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'goals-reply failed',
    });
  }
});

// ============================================
// POST /v2/onboarding/goals-extract
// ============================================

const ExtractBodySchema = z.object({
  conversation: z.array(MessageSchema).min(1).max(60),
  // When true, write the extracted goals into the goals table with embeddings.
  // Default true — the iOS app calls this at the end of onboarding to commit.
  persist: z.boolean().default(true),
});

const ExtractedGoalSchema = z.object({
  title: z.string().min(1).max(120),
  description: z.string().min(1).max(400),
});

const ExtractOutputSchema = z.object({
  goals: z.array(ExtractedGoalSchema).max(6).default([]),
});

v2OnboardingRouter.post('/goals-extract', async (req: Request, res: Response) => {
  try {
    if (!req.user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const parsed = ExtractBodySchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({
        success: false,
        error: 'Invalid body',
        details: parsed.error.errors,
      });
      return;
    }

    const userId = req.user.id;
    const transcript = parsed.data.conversation
      .map((m) => `${m.role === 'user' ? 'User' : 'Retrospect'}: ${m.content}`)
      .join('\n\n');

    const raw = await jsonChatCompletion<unknown>(
      ONBOARDING_GOALS_EXTRACT_SYSTEM,
      `Conversation transcript:\n\n${transcript}\n\nExtract goals per the system prompt.`,
      { temperature: 0.3, maxTokens: 1000 }
    );

    const out = ExtractOutputSchema.safeParse(raw);
    if (!out.success) {
      console.error('[v2:onboarding] extract schema validation failed:', out.error.issues);
      res.status(502).json({
        success: false,
        error: 'Model returned malformed goals',
      });
      return;
    }

    const extracted = out.data.goals;

    // De-dupe by lowercased title within the response itself.
    const seen = new Set<string>();
    const deduped = extracted.filter((g) => {
      const key = g.title.trim().toLowerCase();
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });

    if (!parsed.data.persist || deduped.length === 0) {
      res.json({
        success: true,
        data: { goals: deduped.map((g) => ({ ...g, id: null, persisted: false })) },
      });
      return;
    }

    // Generate embeddings and insert into the goals table.
    const embeddingTexts = deduped.map((g) => `${g.title}\n${g.description}`);
    const embeddings: number[][] = [];
    for (const t of embeddingTexts) {
      embeddings.push(await generateEmbedding(t));
    }

    const rows = deduped.map((g, idx) => ({
      user_id: userId,
      title: g.title,
      description: g.description,
      is_active: true,
      embedding: embeddings[idx] ?? null,
    }));

    const { data: inserted, error: insertErr } = await supabaseAdmin
      .from(Tables.GOALS)
      .insert(rows)
      .select('id, title, description, is_active, created_at');

    if (insertErr) {
      throw new Error(`goals insert failed: ${insertErr.message}`);
    }

    res.json({
      success: true,
      data: { goals: (inserted ?? []).map((g) => ({ ...g, persisted: true })) },
    });
  } catch (err) {
    console.error('[v2:onboarding] goals-extract failed:', err);
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'goals-extract failed',
    });
  }
});
