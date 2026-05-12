/**
 * Stage 2 — historical agent.
 *
 * Runs Claude in a tool-use loop with the 5 research tools. The agent reads the
 * Stage 1 current-context outline and the user's goals/preferences, then pulls
 * older observations, insights, and prior-episode callbacks into a historical
 * outline the script writer can weave with Stage 1.
 *
 * Writes the agent's tool-call trace to agent_tool_traces via the onTrace sink
 * so every run is auditable.
 */

import { supabaseAdmin } from '../../utils/supabase.js';
import { runAgent } from '../agent-runtime/claude-tool-loop.js';
import { historicalAgentTools } from './tools/index.js';
import { STAGE2_HISTORICAL_AGENT_SYSTEM } from './prompts.js';
import type { ToolTraceEvent } from '../agent-runtime/types.js';
import type { DbGoal } from '../../types/index.js';
import type { CurrentContextOutline } from './stage1-current-context.js';
import type { UserPreferences } from './user-preferences.js';

export interface Stage2Input {
  userId: string;
  pipelineRunId: string | null;
  currentContextOutline: CurrentContextOutline;
  goals: DbGoal[];
  preferences: UserPreferences | null;
  /** upper bound on tool-use iterations. default 8. */
  maxSteps?: number;
}

export interface Stage2Output {
  historicalOutline: string;
  toolCalls: ToolTraceEvent[];
  stepsUsed: number;
  stopReason: 'end_turn' | 'max_steps' | 'error';
}

export async function runStage2(input: Stage2Input): Promise<Stage2Output> {
  const today = new Date();
  const userMessage = buildUserMessage(input, today);

  console.log(
    `[v2:stage2] starting historical agent for user=${input.userId} — goals=${input.goals.length}, threads=${input.currentContextOutline.active_threads.length}`
  );

  const result = await runAgent({
    systemPrompt: STAGE2_HISTORICAL_AGENT_SYSTEM,
    userMessage,
    tools: historicalAgentTools,
    context: { userId: input.userId, pipelineRunId: input.pipelineRunId },
    maxSteps: input.maxSteps ?? 8,
    temperature: 0.6,
    maxTokens: 4096,
    onTrace: input.pipelineRunId
      ? (ev) => persistTrace(input.pipelineRunId!, ev)
      : undefined,
  });

  console.log(
    `[v2:stage2] done — stepsUsed=${result.stepsUsed} stopReason=${result.stopReason} toolCalls=${result.toolCalls.length}`
  );

  return {
    historicalOutline: result.finalText,
    toolCalls: result.toolCalls,
    stepsUsed: result.stepsUsed,
    stopReason: result.stopReason,
  };
}

async function persistTrace(pipelineRunId: string, ev: ToolTraceEvent): Promise<void> {
  const { error } = await supabaseAdmin.from('agent_tool_traces').insert({
    pipeline_run_id: pipelineRunId,
    step_index: ev.stepIndex,
    tool_name: ev.toolName,
    tool_input: ev.toolInput as Record<string, unknown>,
    tool_output_summary: ev.toolOutputSummary,
    tool_output_items_count: ev.toolOutputItemsCount,
    duration_ms: ev.durationMs,
    error_message: ev.errorMessage,
  });
  if (error) {
    console.warn('[v2:stage2] failed to persist tool trace:', error.message);
  }
}

function buildUserMessage(input: Stage2Input, today: Date): string {
  const goalLines = input.goals.map(
    (g) => `- [${g.id}] "${g.title}"${g.description ? ` — ${g.description}` : ''}`
  );

  const prefs = input.preferences;
  const prefBlock = prefs
    ? [
        prefs.trusted_voice_description
          ? `- trusted_voice_description: ${prefs.trusted_voice_description}`
          : null,
        prefs.pacing ? `- pacing: ${prefs.pacing}` : null,
        prefs.focus_areas?.length ? `- focus_areas: ${prefs.focus_areas.join(', ')}` : null,
        prefs.avoid_topics?.length ? `- avoid_topics: ${prefs.avoid_topics.join(', ')}` : null,
        prefs.last_podcast_feedback
          ? `- last_podcast_feedback: ${prefs.last_podcast_feedback}`
          : null,
      ]
        .filter(Boolean)
        .join('\n')
    : '(none)';

  return `Today is ${today.toISOString().slice(0, 10)}.

## CURRENT-CONTEXT OUTLINE (from Stage 1, covers roughly the last 2 weeks)
${JSON.stringify(input.currentContextOutline, null, 2)}

## ACTIVE GOALS
${goalLines.join('\n') || '(none)'}

## USER PREFERENCES
${prefBlock}

Do your research now. Follow the tool-use workflow in the system prompt.
Start by calling search_previous_podcasts with recent=true so you know what NOT to repeat.
Then reach into older observations and insights to build the historical outline.
When you have enough, return your final Markdown outline — do not call any more tools.`;
}
