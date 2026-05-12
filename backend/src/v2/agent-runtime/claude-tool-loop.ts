/**
 * Generic Claude tool-use loop.
 *
 * Given a system prompt, an initial user message, and a set of tools, this runs
 * Claude in a loop: if the assistant returns tool_use content blocks, we execute
 * each tool, append tool_result messages, and call the model again. We stop when
 * Claude returns end_turn (final text), when we hit the max step budget, or when
 * a tool throws.
 *
 * The runtime is deliberately generic — it knows nothing about podcasts or
 * observations. Tools own their own schemas and effects. Trace events are emitted
 * to an optional sink so callers can persist them to agent_tool_traces.
 *
 * See backend/src/v2/podcast/stage2-historical-agent.ts for the first caller.
 */

import Anthropic from '@anthropic-ai/sdk';
import { config } from '../../utils/config.js';
import type {
  AgentRunContext,
  AgentRunResult,
  AgentTool,
  ToolTraceEvent,
  ToolTraceSink,
} from './types.js';

const anthropic = new Anthropic({ apiKey: config.anthropic.apiKey });

export interface RunAgentOptions {
  systemPrompt: string;
  /** initial user turn */
  userMessage: string;
  // Heterogenous list of tools — each tool is generic over its own input/output,
  // so we accept `AgentTool<any, any>` here to avoid TS variance issues at the
  // call site (e.g. tools/index.ts).
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  tools: AgentTool<any, any>[];
  context: AgentRunContext;
  /** upper bound on (assistant turn) iterations before we force end. default 10. */
  maxSteps?: number;
  /** Claude model override. default config.anthropic.model */
  model?: string;
  /** temperature for assistant turns. default 0.7 */
  temperature?: number;
  /** max output tokens per assistant turn. default 4096 */
  maxTokens?: number;
  /** optional trace sink for observability */
  onTrace?: ToolTraceSink;
}

interface AssistantTurnResponse {
  stop_reason: Anthropic.Messages.Message['stop_reason'];
  content: Anthropic.Messages.ContentBlock[];
}

export async function runAgent(opts: RunAgentOptions): Promise<AgentRunResult> {
  const {
    systemPrompt,
    userMessage,
    tools,
    context,
    maxSteps = 10,
    model = config.anthropic.model,
    temperature = 0.7,
    maxTokens = 4096,
    onTrace,
  } = opts;

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const toolRegistry = new Map<string, AgentTool<any, any>>();
  for (const t of tools) toolRegistry.set(t.name, t);

  const toolDefs: Anthropic.Messages.Tool[] = tools.map((t) => ({
    name: t.name,
    description: t.description,
    input_schema: t.input_schema as Anthropic.Messages.Tool['input_schema'],
  }));

  const messages: Anthropic.Messages.MessageParam[] = [
    { role: 'user', content: userMessage },
  ];

  const toolCalls: ToolTraceEvent[] = [];
  let stepIndex = 0;

  while (stepIndex < maxSteps) {
    const response: AssistantTurnResponse = await anthropic.messages.create({
      model,
      system: systemPrompt,
      tools: toolDefs,
      messages,
      temperature,
      max_tokens: maxTokens,
    });

    // Append the assistant's turn (including any tool_use blocks) so the next
    // request has the full conversation history.
    messages.push({ role: 'assistant', content: response.content });

    if (response.stop_reason === 'end_turn' || response.stop_reason === 'stop_sequence') {
      const text = extractText(response.content);
      return {
        finalText: text,
        stepsUsed: stepIndex + 1,
        stopReason: 'end_turn',
        toolCalls,
      };
    }

    if (response.stop_reason !== 'tool_use') {
      // Unexpected stop (e.g. max_tokens). Return what we have so the caller can decide.
      const text = extractText(response.content);
      return {
        finalText: text,
        stepsUsed: stepIndex + 1,
        stopReason: 'end_turn',
        toolCalls,
      };
    }

    const toolUseBlocks = response.content.filter(
      (b): b is Anthropic.Messages.ToolUseBlock => b.type === 'tool_use'
    );

    // Execute tools (in parallel). If one fails we still report tool_result
    // for the others so Claude can continue reasoning.
    const toolResultBlocks: Anthropic.Messages.ToolResultBlockParam[] = await Promise.all(
      toolUseBlocks.map(async (block) => {
        const tool = toolRegistry.get(block.name);
        const startedAt = Date.now();
        if (!tool) {
          const msg = `Unknown tool: ${block.name}`;
          const trace: ToolTraceEvent = {
            stepIndex,
            toolName: block.name,
            toolInput: block.input,
            toolOutputSummary: msg,
            toolOutputItemsCount: null,
            durationMs: 0,
            errorMessage: msg,
          };
          toolCalls.push(trace);
          if (onTrace) await onTrace(trace);
          return {
            type: 'tool_result' as const,
            tool_use_id: block.id,
            content: msg,
            is_error: true,
          };
        }
        try {
          const output = await tool.execute(block.input, context);
          const summary = tool.summarize
            ? tool.summarize(output)
            : summarizeDefault(output);
          const trace: ToolTraceEvent = {
            stepIndex,
            toolName: block.name,
            toolInput: block.input,
            toolOutputSummary: summary.text,
            toolOutputItemsCount: summary.itemsCount ?? null,
            durationMs: Date.now() - startedAt,
            errorMessage: null,
          };
          toolCalls.push(trace);
          if (onTrace) await onTrace(trace);
          // Serialize output for Claude as a JSON string — tools should return
          // model-friendly shapes (plain objects / arrays) that JSON.stringify cleanly.
          return {
            type: 'tool_result' as const,
            tool_use_id: block.id,
            content: safeStringify(output),
          };
        } catch (err) {
          const message = err instanceof Error ? err.message : String(err);
          const trace: ToolTraceEvent = {
            stepIndex,
            toolName: block.name,
            toolInput: block.input,
            toolOutputSummary: `ERROR: ${message}`,
            toolOutputItemsCount: null,
            durationMs: Date.now() - startedAt,
            errorMessage: message,
          };
          toolCalls.push(trace);
          if (onTrace) await onTrace(trace);
          return {
            type: 'tool_result' as const,
            tool_use_id: block.id,
            content: `Tool error: ${message}`,
            is_error: true,
          };
        }
      })
    );

    messages.push({ role: 'user', content: toolResultBlocks });
    stepIndex += 1;
  }

  // Max steps exhausted. Ask the model one last time to produce a final answer
  // without calling any tools, so the caller still gets useful text.
  const finalResponse = await anthropic.messages.create({
    model,
    system: `${systemPrompt}\n\nIMPORTANT: You have reached the maximum tool-call budget. Produce your final answer now using only the information gathered so far. Do not request any more tool calls.`,
    messages,
    temperature,
    max_tokens: maxTokens,
  });

  return {
    finalText: extractText(finalResponse.content),
    stepsUsed: maxSteps,
    stopReason: 'max_steps',
    toolCalls,
  };
}

function extractText(content: Anthropic.Messages.ContentBlock[]): string {
  const parts: string[] = [];
  for (const block of content) {
    if (block.type === 'text') parts.push(block.text);
  }
  return parts.join('\n').trim();
}

function summarizeDefault(output: unknown): { text: string; itemsCount?: number } {
  if (Array.isArray(output)) {
    return { text: `array(${output.length})`, itemsCount: output.length };
  }
  if (output && typeof output === 'object') {
    const obj = output as Record<string, unknown>;
    // Look for common list-shaped fields so trace rows carry useful counts.
    for (const k of ['results', 'items', 'observations', 'insights', 'episodes', 'citations']) {
      const v = obj[k];
      if (Array.isArray(v)) {
        return { text: `${k}(${v.length})`, itemsCount: v.length };
      }
    }
    return { text: safeStringify(output).slice(0, 300) };
  }
  return { text: String(output).slice(0, 300) };
}

function safeStringify(value: unknown): string {
  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
}
