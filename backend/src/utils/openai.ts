/**
 * AI Utilities
 *
 * Claude (Anthropic) — all intelligence tasks: extraction, synthesis, analysis
 * OpenAI — embeddings only (Anthropic doesn't offer an embedding model)
 *
 * This file keeps the same exports (generateEmbedding, generateEmbeddings,
 * chatCompletion, jsonChatCompletion) so no other files need to change.
 */

import Anthropic from '@anthropic-ai/sdk';
import OpenAI from 'openai';
import { config } from './config.js';

// Anthropic client — for thinking tasks
const anthropic = new Anthropic({
  apiKey: config.anthropic.apiKey,
});

// OpenAI client — for embeddings only
const openai = new OpenAI({
  apiKey: config.openai.apiKey,
});

// ============================================
// EMBEDDINGS (OpenAI — unchanged)
// ============================================

export async function generateEmbedding(text: string): Promise<number[]> {
  const response = await openai.embeddings.create({
    model: config.openai.embeddingModel,
    input: text,
    dimensions: config.embeddings.dimensions,
  });

  const embedding = response.data[0]?.embedding;
  if (!embedding) {
    throw new Error('Failed to generate embedding');
  }

  return embedding;
}

export async function generateEmbeddings(texts: string[]): Promise<number[][]> {
  if (texts.length === 0) return [];

  const batches: string[][] = [];
  for (let i = 0; i < texts.length; i += config.embeddings.batchSize) {
    batches.push(texts.slice(i, i + config.embeddings.batchSize));
  }

  const allEmbeddings: number[][] = [];

  for (const batch of batches) {
    const response = await openai.embeddings.create({
      model: config.openai.embeddingModel,
      input: batch,
      dimensions: config.embeddings.dimensions,
    });

    const batchEmbeddings = response.data.map((d) => d.embedding);
    allEmbeddings.push(...batchEmbeddings);
  }

  return allEmbeddings;
}

// ============================================
// CHAT COMPLETIONS (Claude)
// ============================================

export async function chatCompletion(
  systemPrompt: string,
  userMessage: string,
  options?: {
    temperature?: number;
    maxTokens?: number;
    responseFormat?: 'text' | 'json_object';
  }
): Promise<string> {
  // If JSON is requested, reinforce it in the system prompt
  const finalSystemPrompt =
    options?.responseFormat === 'json_object'
      ? `${systemPrompt}\n\nIMPORTANT: You MUST respond with valid JSON only. No markdown, no code fences, no explanation outside the JSON.`
      : systemPrompt;

  const response = await anthropic.messages.create({
    model: config.anthropic.model,
    system: finalSystemPrompt,
    messages: [
      { role: 'user', content: userMessage },
    ],
    temperature: options?.temperature ?? 0.3,
    max_tokens: options?.maxTokens ?? 4096,
  });

  // Extract text from Claude's response
  const textBlock = response.content.find((block) => block.type === 'text');
  if (!textBlock || textBlock.type !== 'text') {
    throw new Error('No text response from Claude');
  }

  return textBlock.text;
}

export async function jsonChatCompletion<T>(
  systemPrompt: string,
  userMessage: string,
  options?: {
    temperature?: number;
    maxTokens?: number;
  }
): Promise<T> {
  const response = await chatCompletion(systemPrompt, userMessage, {
    ...options,
    responseFormat: 'json_object',
  });

  // Claude sometimes wraps JSON in markdown code fences — strip them
  let cleaned = response.trim();
  if (cleaned.startsWith('```json')) {
    cleaned = cleaned.slice(7);
  } else if (cleaned.startsWith('```')) {
    cleaned = cleaned.slice(3);
  }
  if (cleaned.endsWith('```')) {
    cleaned = cleaned.slice(0, -3);
  }
  cleaned = cleaned.trim();

  try {
    return JSON.parse(cleaned) as T;
  } catch {
    throw new Error(`Failed to parse JSON response from Claude: ${cleaned.slice(0, 200)}`);
  }
}
