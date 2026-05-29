import { Router, Request, Response } from 'express';
import Anthropic from '@anthropic-ai/sdk';

export const claudeRouter = Router();

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
    const { systemPrompt, userMessage, messages, maxTokens = 2000 } = req.body;

    const messageList = (
      messages ?? (userMessage != null ? [{ role: 'user', content: userMessage }] : null)
    ) as Anthropic.MessageParam[] | null;

    if (!messageList || messageList.length === 0) {
      res.status(400).json({ success: false, error: 'messages or userMessage is required' });
      return;
    }

    const params: Anthropic.MessageCreateParamsNonStreaming = {
      model: 'claude-sonnet-4-20250514',
      max_tokens: Math.min(Number(maxTokens), 8192),
      messages: messageList,
    };

    if (systemPrompt) {
      params.system = systemPrompt as string;
    }

    const message = await getClient().messages.create(params);
    const text = message.content[0]?.type === 'text' ? message.content[0].text : '';
    res.json({ success: true, data: { text } });
  } catch (err) {
    console.error('[claude] generation error:', err);
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'Claude generation failed',
    });
  }
});
