/**
 * What a person's verdict on a fact means for the brain (goal 20). "Contradict"
 * says it was wrong: rejected, and never brought back. "Retire" says it's no
 * longer true: retired as of now, but believed again if they say it again.
 * "Confirm" changes nothing to correct.
 */
export type FeedbackDecision = 'confirm' | 'contradict' | 'retire';

export function correctionMode(decision: FeedbackDecision): 'wrong' | 'changed' | null {
  if (decision === 'contradict') return 'wrong';
  if (decision === 'retire') return 'changed';
  return null;
}
