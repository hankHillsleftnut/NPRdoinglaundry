import { Router } from 'express';
import { randomUUID } from 'crypto';
import { z } from 'zod';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import { applyAgentCorrection } from '../services/agent-client.js';
import { correctionMode } from '../services/assertion-feedback.js';

export const graphRouter = Router();

graphRouter.get('/assertions', async (req, res) => {
  try {
    const limit = Math.min(200, Math.max(1, Number(req.query.limit ?? 100)));
    let query = supabaseAdmin
      .from(Tables.ASSERTIONS)
      .select('id,predicate,object_entity_id,object_value,assertion_kind,confidence,event_time,observed_at,valid_from,valid_to,status,metadata,entities!assertions_subject_entity_id_fkey(id,entity_type,canonical_name),assertion_evidence(id,evidence_role,weight,excerpt,source_item_id,raw_content_id)')
      .eq('user_id', req.user!.id)
      .order('observed_at', { ascending: false })
      .limit(limit);
    if (typeof req.query.kind === 'string') query = query.eq('assertion_kind', req.query.kind);
    if (typeof req.query.status === 'string') query = query.eq('status', req.query.status);
    const { data, error } = await query;
    if (error) throw error;
    res.json({ success: true, data: data ?? [] });
  } catch (err) {
    res.status(500).json({ success: false, error: err instanceof Error ? err.message : 'Failed to load assertions' });
  }
});

graphRouter.get('/entity-resolution-candidates', async (req, res) => {
  try {
    const { data, error } = await supabaseAdmin.from(Tables.ENTITY_RESOLUTION_CANDIDATES)
      .select('id,confidence,signals,status,created_at,left:entities!entity_resolution_candidates_left_entity_id_fkey(id,entity_type,canonical_name,attributes),right:entities!entity_resolution_candidates_right_entity_id_fkey(id,entity_type,canonical_name,attributes)')
      .eq('user_id', req.user!.id)
      .eq('status', 'pending')
      .order('confidence', { ascending: false })
      .limit(100);
    if (error) throw error;
    res.json({ success: true, data: data ?? [] });
  } catch (err) {
    res.status(500).json({ success: false, error: err instanceof Error ? err.message : 'Failed to load entity resolution candidates' });
  }
});

const entityResolutionSchema = z.object({ decision: z.enum(['accepted', 'rejected']) });

graphRouter.post('/entity-resolution-candidates/:candidateId/feedback', async (req, res) => {
  const parsed = entityResolutionSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ success: false, error: 'Invalid entity resolution decision' });
    return;
  }
  try {
    const { error } = await supabaseAdmin.rpc('resolve_entity_candidate', {
      p_user_id: req.user!.id,
      p_candidate_id: req.params.candidateId,
      p_decision: parsed.data.decision,
    });
    if (error) throw error;
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err instanceof Error ? err.message : 'Failed to resolve entities' });
  }
});

const feedbackSchema = z.object({
  decision: z.enum(['confirm', 'contradict', 'retire']),
  note: z.string().max(2000).optional(),
});

graphRouter.post('/assertions/:assertionId/feedback', async (req, res) => {
  const parsed = feedbackSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ success: false, error: 'Invalid assertion feedback' });
    return;
  }
  try {
    const { data: assertion, error: loadError } = await supabaseAdmin
      .from(Tables.ASSERTIONS)
      .select('id,subject_entity_id,predicate,object_entity_id,object_value,metadata')
      .eq('id', req.params.assertionId)
      .eq('user_id', req.user!.id)
      .single();
    if (loadError || !assertion) {
      res.status(404).json({ success: false, error: 'Assertion not found' });
      return;
    }
    // Goal 20: "retire" (no longer true) and "contradict" (was wrong) go through the
    // agent's correction path, which retires everything resting only on this fact
    // and, for "contradict", keeps it from ever coming back. It no longer writes a
    // marker copy of the fact, which stayed active and showed in search (finding 51).
    const mode = correctionMode(parsed.data.decision);
    if (mode) {
      await supabaseAdmin.from(Tables.ASSERTIONS)
        .update({ metadata: { ...assertion.metadata, user_feedback_note: parsed.data.note ?? null } })
        .eq('id', assertion.id)
        .eq('user_id', req.user!.id);
      await applyAgentCorrection({
        userId: req.user!.id, kind: 'fact', id: assertion.id, note: parsed.data.note ?? null,
        mode,
      });
    } else {
      const { data: feedbackAssertion, error: feedbackError } = await supabaseAdmin.from(Tables.ASSERTIONS)
        .insert({
          user_id: req.user!.id,
          subject_entity_id: assertion.subject_entity_id,
          predicate: assertion.predicate,
          object_entity_id: assertion.object_entity_id,
          object_value: assertion.object_value,
          assertion_kind: 'user_confirmed',
          confidence: 1,
          observed_at: new Date().toISOString(),
          status: 'active',
          origin_key: `user_feedback:${randomUUID()}`,
          metadata: {
            user_feedback_note: parsed.data.note ?? null,
            target_assertion_id: assertion.id,
            decision: parsed.data.decision,
          },
        })
        .select('id')
        .single();
      if (feedbackError || !feedbackAssertion) throw feedbackError ?? new Error('Feedback assertion was not created');
      const { error: relationError } = await supabaseAdmin.from(Tables.ASSERTION_RELATIONS).insert({
        user_id: req.user!.id,
        from_assertion_id: feedbackAssertion.id,
        to_assertion_id: assertion.id,
        relation_type: 'supports',
        confidence: 1,
        metadata: { source: 'user_feedback' },
      });
      if (relationError) throw relationError;
    }

    const inferenceId = typeof assertion.metadata?.identity_inference_id === 'string'
      ? assertion.metadata.identity_inference_id
      : null;
    if (inferenceId) {
      await supabaseAdmin.from(Tables.IDENTITY_INFERENCES).update(
        parsed.data.decision === 'confirm'
          ? { is_provisional: false }
          : { retired_at: new Date().toISOString(), retirement_reason: `User ${parsed.data.decision}: ${parsed.data.note ?? ''}`.trim() }
      ).eq('id', inferenceId).eq('user_id', req.user!.id);
    }
    await supabaseAdmin.from(Tables.INTEGRATION_AUDIT_EVENTS).insert({
      user_id: req.user!.id,
      actor_type: 'user',
      actor_id: req.user!.id,
      event_type: 'assertion_feedback',
      event_data: { assertion_id: assertion.id, decision: parsed.data.decision, note: parsed.data.note ?? null },
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err instanceof Error ? err.message : 'Failed to save assertion feedback' });
  }
});
