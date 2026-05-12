/**
 * Shared types for the v2 Claude tool-use agent runtime.
 */

export type JsonSchema = Record<string, unknown>;

/**
 * A Tool the agent can invoke. The runtime is generic over the input/output shapes;
 * tools own their own validation. Keep `execute` pure from the runtime's perspective —
 * it should only read/write via the ctx it is handed.
 */
export interface AgentTool<TInput = unknown, TOutput = unknown> {
  name: string;
  description: string;
  input_schema: JsonSchema;
  execute: (input: TInput, ctx: AgentRunContext) => Promise<TOutput>;
  /**
   * Optional summarizer so the trace writer doesn't dump full tool output into
   * the database. Defaults to a shallow JSON string-truncated version.
   */
  summarize?: (output: TOutput) => { text: string; itemsCount?: number };
}

export interface AgentRunContext {
  userId: string;
  /** pipeline_runs.id, used to tag trace rows */
  pipelineRunId: string | null;
}

export interface ToolTraceEvent {
  stepIndex: number;
  toolName: string;
  toolInput: unknown;
  toolOutputSummary: string;
  toolOutputItemsCount: number | null;
  durationMs: number;
  errorMessage: string | null;
}

export type ToolTraceSink = (event: ToolTraceEvent) => Promise<void> | void;

export interface AgentRunResult {
  finalText: string;
  stepsUsed: number;
  stopReason: 'end_turn' | 'max_steps' | 'error';
  toolCalls: ToolTraceEvent[];
}
