import { Router, Request, Response } from 'express';
import Anthropic from '@anthropic-ai/sdk';
import { CallLog, guardClaudeRequest } from '../services/claude-guard.js';

export const claudeRouter = Router();
const callLog = new CallLog();

let _client: Anthropic | null = null;
function getClient(): Anthropic {
  if (!_client) {
    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) throw new Error('ANTHROPIC_API_KEY is not configured on the server');
    _client = new Anthropic({ apiKey });
  }
  return _client;
}

// POST /claude/generate
// Body: { systemPrompt?, userMessage?, messages?, maxTokens? }
// Returns: { success: true, data: { text: string } }
claudeRouter.post('/generate', async (req: Request, res: Response) => {
  try {
    const guard = guardClaudeRequest(req.user?.id, req.body, callLog);
    if (!guard.ok) {
      res.status(guard.status).json({ success: false, error: guard.error });
      return;
    }

    const params: Anthropic.MessageCreateParamsNonStreaming = {
      model: process.env.CLAUDE_MODEL || 'claude-sonnet-4-6',
      max_tokens: guard.maxTokens,
      messages: guard.messages,
    };
    if (guard.system) params.system = guard.system;

    const message = await getClient().messages.create(params);
    const text = message.content[0]?.type === 'text' ? message.content[0].text : '';
    res.json({ success: true, data: { text } });
  } catch (err) {
    console.error('[claude] generation error:', err);
    res.status(500).json({
      success: false,
      error: 'Claude generation failed',
    });
  }
});
