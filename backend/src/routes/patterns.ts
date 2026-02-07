import { Router, Request, Response } from 'express';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import {
  getUserPatterns,
  updatePatternFeedback,
  getPatternWithInsights,
  detectDailyPatterns,
} from '../services/patterns.js';
import { PatternFeedbackSchema, PatternTypeSchema } from '../types/index.js';

export const patternsRouter = Router();

// GET /patterns - List patterns
patternsRouter.get('/', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const activeOnly = req.query.activeOnly !== 'false';
    const patternType = req.query.type as string;
    const limit = Math.min(parseInt(req.query.limit as string) || 50, 100);

    // Validate pattern type if provided
    if (patternType) {
      const typeResult = PatternTypeSchema.safeParse(patternType);
      if (!typeResult.success) {
        res.status(400).json({
          success: false,
          error: 'Invalid pattern type',
        });
        return;
      }
    }

    const patterns = await getUserPatterns(user.id, {
      activeOnly,
      patternType: patternType as any,
      limit,
    });

    // Transform to camelCase
    const transformedPatterns = patterns.map((p) => ({
      id: p.id,
      title: p.title,
      description: p.description,
      patternType: p.pattern_type,
      categories: p.categories,
      supportingInsightIds: p.supporting_insight_ids,
      confidenceScore: p.confidence_score,
      frequency: p.frequency,
      timeRangeStart: p.time_range_start,
      timeRangeEnd: p.time_range_end,
      isActive: p.is_active,
      userAcknowledged: p.user_acknowledged,
      userFeedback: p.user_feedback,
      createdAt: p.created_at,
      lastValidatedAt: p.last_validated_at,
    }));

    res.json({
      success: true,
      data: transformedPatterns,
    });
  } catch (error) {
    console.error('List patterns error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to list patterns',
    });
  }
});

// GET /patterns/:id - Get pattern with supporting insights
patternsRouter.get('/:id', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const result = await getPatternWithInsights(req.params.id!, user.id);

    if (!result) {
      res.status(404).json({
        success: false,
        error: 'Pattern not found',
      });
      return;
    }

    const { pattern, supportingInsights } = result;

    res.json({
      success: true,
      data: {
        pattern: {
          id: pattern.id,
          title: pattern.title,
          description: pattern.description,
          patternType: pattern.pattern_type,
          categories: pattern.categories,
          confidenceScore: pattern.confidence_score,
          frequency: pattern.frequency,
          timeRangeStart: pattern.time_range_start,
          timeRangeEnd: pattern.time_range_end,
          isActive: pattern.is_active,
          userAcknowledged: pattern.user_acknowledged,
          userFeedback: pattern.user_feedback,
          feedbackNotes: pattern.feedback_notes,
          createdAt: pattern.created_at,
          lastValidatedAt: pattern.last_validated_at,
        },
        supportingInsights: supportingInsights.map((i) => ({
          id: i.id,
          content: i.content,
          primaryCategory: i.primary_category,
          insightDate: i.insight_date,
          sentiment: i.sentiment,
          intensity: i.intensity,
        })),
      },
    });
  } catch (error) {
    console.error('Get pattern error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get pattern',
    });
  }
});

// PUT /patterns/:id/feedback - Provide feedback on a pattern
patternsRouter.put('/:id/feedback', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const validationResult = PatternFeedbackSchema.safeParse(req.body);
    if (!validationResult.success) {
      res.status(400).json({
        success: false,
        error: 'Invalid request body',
        details: validationResult.error.errors,
      });
      return;
    }

    const { feedback, notes } = validationResult.data;

    await updatePatternFeedback(req.params.id!, user.id, feedback, notes);

    res.json({
      success: true,
      message: 'Feedback recorded',
    });
  } catch (error) {
    console.error('Pattern feedback error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to record feedback',
    });
  }
});

// POST /patterns/detect - Manually trigger pattern detection
patternsRouter.post('/detect', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const result = await detectDailyPatterns(user.id);

    res.json({
      success: true,
      data: {
        newPatterns: result.newPatterns,
        analysisNotes: result.analysisNotes,
      },
    });
  } catch (error) {
    console.error('Pattern detection error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to detect patterns',
    });
  }
});

// DELETE /patterns/:id - Delete/dismiss a pattern
patternsRouter.delete('/:id', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    // Soft delete by deactivating
    const { error } = await supabaseAdmin
      .from(Tables.PATTERNS)
      .update({ is_active: false })
      .eq('id', req.params.id)
      .eq('user_id', user.id);

    if (error) {
      throw error;
    }

    res.json({
      success: true,
      message: 'Pattern dismissed',
    });
  } catch (error) {
    console.error('Delete pattern error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete pattern',
    });
  }
});

// GET /patterns/summary - Get pattern summary stats
patternsRouter.get('/stats/summary', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const { data: patterns, error } = await supabaseAdmin
      .from(Tables.PATTERNS)
      .select('pattern_type, is_active, user_feedback')
      .eq('user_id', user.id);

    if (error) {
      throw error;
    }

    const summary = {
      total: patterns?.length || 0,
      active: patterns?.filter((p) => p.is_active).length || 0,
      byType: {} as Record<string, number>,
      confirmed: patterns?.filter((p) => p.user_feedback === 'confirmed').length || 0,
      rejected: patterns?.filter((p) => p.user_feedback === 'rejected').length || 0,
      pending: patterns?.filter((p) => !p.user_feedback && p.is_active).length || 0,
    };

    for (const pattern of patterns || []) {
      const type = pattern.pattern_type;
      summary.byType[type] = (summary.byType[type] || 0) + 1;
    }

    res.json({
      success: true,
      data: summary,
    });
  } catch (error) {
    console.error('Pattern summary error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get pattern summary',
    });
  }
});
