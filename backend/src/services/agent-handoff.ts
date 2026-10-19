/**
 * Handing a stored upload to the agent for processing.
 *
 * This function is deliberately never given a database client. That is the
 * point of it: it cannot write a row's processing status, so it cannot repeat
 * the bug that stranded 2,024 rows in production -- the upload route writing a
 * bare `failed` over the agent's retry scheduling.
 *
 * Making the wrong thing impossible is stronger than testing that it does not
 * happen. A test can be deleted along with the line it guards; a missing
 * parameter has to be added on purpose, and the reason it is absent is written
 * here.
 */

export interface HandOffArgs {
  userId: string;
  rawContentIds: string[];
}

/**
 * Start agent ingestion for some rows, and never fail the caller over it.
 *
 * Success and failure are both the agent's to record. If the agent cannot be
 * reached, the rows stay `pending` -- the state they were inserted in -- and the
 * agent picks every pending row up on a later run, including ones older than
 * its usual window.
 */
export async function handOffToAgent(
  ingest: (args: HandOffArgs) => Promise<unknown>,
  args: HandOffArgs,
  log: (message: string, error: unknown) => void = (m, e) => console.error(m, e),
): Promise<void> {
  try {
    await ingest(args);
  } catch (error) {
    log(
      '[content] Could not reach the agent; the row stays pending and will be picked up on its next run:',
      error,
    );
  }
}
