// ---------------------------------------------------------------------------
// The vocabulary of the canvas.
//
// The guiding rule, and the reason several of these states exist separately:
// a card must never claim health it cannot prove. "I have no telemetry",
// "I have telemetry and it says nothing ran recently", and "my query failed"
// are three different sentences, and collapsing them is how a dashboard starts
// lying. Hence `notInstrumented`, `idle` and `unknown` are distinct.
// ---------------------------------------------------------------------------

export type Health =
  | 'ok'              // ran inside the window, no failures
  | 'degraded'        // ran, but some failures / warning signal
  | 'failed'          // the dominant recent outcome is failure
  | 'idle'            // has history, but nothing inside the window
  | 'never'           // the table has never held a row for this bucket
  | 'notInstrumented' // nothing records this step; we say so
  | 'unknown';        // the read itself failed — never render as healthy

export type RegionId =
  | 'capture'
  | 'api'
  | 'integrations'
  | 'ingest'
  | 'brain'
  | 'podcast'
  | 'sinks';

/** One (source, bucket, status) aggregate. The atom the whole board is built from. */
export type RollupFact = {
  source: string;
  bucket: string;
  status: string;
  n: number;
  /** of `n`, how many fall inside the recent window (see SourceMeta.kind) */
  recentN: number;
  lastAt: string | null;
  lastLabel: string | null;
};

export type SourceMeta = {
  /**
   * 'state' -- a row's status describes how things ARE now. A failed row is a
   *   standing problem (an unprocessed entry still sitting there), so it counts
   *   against health no matter how old it is.
   * 'event' -- a row records something that HAPPENED. A run that failed in May
   *   is history, not a current fault, so health is judged on the recent window
   *   and the all-time figure is reported alongside rather than driving colour.
   *
   * Getting this wrong in either direction makes the board lie: treat events as
   * state and it can never show recovery; treat state as events and a backlog
   * of 2,000 dead entries silently turns green.
   */
  kind: 'state' | 'event';
  /** total rows seen for this source */
  total: number;
  /** true when we hit the row cap and the counts below are a floor, not a total */
  truncated: boolean;
  /** set when the read failed; forces every node on this source to `unknown` */
  error: string | null;
};

export type Snapshot = {
  takenAt: string;
  windowHours: number;
  facts: RollupFact[];
  sources: Record<string, SourceMeta>;
};

/** How a node derives its health. */
export type Probe =
  | {
      kind: 'rollup';
      source: string;
      /** omit to match every bucket in the source */
      bucket?: string | string[];
      /** when set, ONLY these statuses are counted at all -- used by sinks, which
       *  are about one outcome and should report that outcome's size, not the
       *  size of the table they happen to live in */
      only?: string[];
      okStatuses?: string[];
      warnStatuses?: string[];
      failStatuses?: string[];
    }
  | {
      kind: 'notInstrumented';
      /** why this step is invisible today */
      reason: string;
      /** the specific change that would light it up */
      wouldNeed: string;
    };

export type NodeSpec = {
  id: string;
  title: string;
  /** one plain sentence: what this step is for. Mandatory — enforced in CI. */
  purpose: string;
  region: RegionId;
  /** file:line this node stands for */
  source?: string;
  /** which sub-column within the region, for layout */
  column?: number;
  order: number;
  probe: Probe;
  /** rendered as a warning chip on the card */
  caveat?: string;
  /**
   * Part of the second-brain work: the span-verified fact bank, the promoter,
   * the why gate and everything built on them. Marked so the new machinery can
   * be told apart from the pipeline that was already running around it.
   */
  isNew?: boolean;
  /**
   * Superseded by the new machinery and kept only so existing surfaces keep
   * working -- the removal list.
   *
   * Deliberately NOT "everything that isn't new". The iPhone app, the API and
   * the connectors are not old, they are the live product; nothing has replaced
   * them. Only steps the second brain actually supersedes are marked, so this
   * tag stays a decision you can act on rather than a label on two-thirds of
   * the board.
   */
  isLegacy?: boolean;
};

export type EdgeSpec = {
  from: string;
  to: string;
  /** flow = happy path; branch = loss/diversion; inferred = real but unprovable */
  kind: 'flow' | 'branch' | 'inferred';
  label?: string;
};

export type NodeState = {
  id: string;
  health: Health;
  lastAt: string | null;
  lastLabel: string | null;
  total: number;
  failed: number;
  detail: string;
};
