import { Router, Request, Response } from 'express';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import {
  getInsightConnections,
  searchInsightsSemantic,
} from '../services/connections.js';
import {
  ListInsightsQuerySchema,
  SearchInsightsSchema,
} from '../types/index.js';

export const insightsRouter = Router();

// GET /insights - List insights with filters
insightsRouter.get('/', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    // Validate query parameters
    const queryResult = ListInsightsQuerySchema.safeParse(req.query);
    if (!queryResult.success) {
      res.status(400).json({
        success: false,
        error: 'Invalid query parameters',
        details: queryResult.error.errors,
      });
      return;
    }

    const { category, startDate, endDate, isInferred, sentiment, limit, offset } =
      queryResult.data;

    // Build query
    let query = supabaseAdmin
      .from(Tables.INSIGHT_UNITS)
      .select(
        `
        id,
        content,
        primary_category,
        secondary_categories,
        is_inferred,
        confidence_score,
        inference_reasoning,
        insight_date,
        sentiment,
        emotion_tags,
        intensity,
        created_at
      `,
        { count: 'exact' }
      )
      .eq('user_id', user.id)
      .order('insight_date', { ascending: false })
      .range(offset, offset + limit - 1);

    if (category) {
      query = query.eq('primary_category', category);
    }

    if (startDate) {
      query = query.gte('insight_date', startDate);
    }

    if (endDate) {
      query = query.lte('insight_date', endDate);
    }

    if (isInferred !== undefined) {
      query = query.eq('is_inferred', isInferred === 'true');
    }

    if (sentiment) {
      query = query.eq('sentiment', sentiment);
    }

    const { data, error, count } = await query;

    if (error) {
      throw error;
    }

    // Transform to camelCase for API response
    const transformedData = (data || []).map((insight) => ({
      id: insight.id,
      content: insight.content,
      primaryCategory: insight.primary_category,
      secondaryCategories: insight.secondary_categories,
      isInferred: insight.is_inferred,
      confidenceScore: insight.confidence_score,
      inferenceReasoning: insight.inference_reasoning,
      insightDate: insight.insight_date,
      sentiment: insight.sentiment,
      emotionTags: insight.emotion_tags,
      intensity: insight.intensity,
      createdAt: insight.created_at,
    }));

    res.json({
      success: true,
      data: transformedData,
      pagination: {
        total: count || 0,
        limit,
        offset,
        hasMore: (count || 0) > offset + limit,
      },
    });
  } catch (error) {
    console.error('List insights error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to list insights',
    });
  }
});

// GET /insights/:id - Get single insight
insightsRouter.get('/:id', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const { data, error } = await supabaseAdmin
      .from(Tables.INSIGHT_UNITS)
      .select('*')
      .eq('id', req.params.id)
      .eq('user_id', user.id)
      .single();

    if (error || !data) {
      res.status(404).json({
        success: false,
        error: 'Insight not found',
      });
      return;
    }

    res.json({
      success: true,
      data: {
        id: data.id,
        content: data.content,
        primaryCategory: data.primary_category,
        secondaryCategories: data.secondary_categories,
        isInferred: data.is_inferred,
        confidenceScore: data.confidence_score,
        inferenceReasoning: data.inference_reasoning,
        insightDate: data.insight_date,
        sentiment: data.sentiment,
        emotionTags: data.emotion_tags,
        intensity: data.intensity,
        metadata: data.metadata,
        createdAt: data.created_at,
        updatedAt: data.updated_at,
      },
    });
  } catch (error) {
    console.error('Get insight error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get insight',
    });
  }
});

// GET /insights/:id/connections - Get connections for an insight
insightsRouter.get('/:id/connections', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    // Verify insight belongs to user
    const { data: insight, error: insightError } = await supabaseAdmin
      .from(Tables.INSIGHT_UNITS)
      .select('id')
      .eq('id', req.params.id)
      .eq('user_id', user.id)
      .single();

    if (insightError || !insight) {
      res.status(404).json({
        success: false,
        error: 'Insight not found',
      });
      return;
    }

    const depth = Math.min(parseInt(req.query.depth as string) || 1, 3);
    const connections = await getInsightConnections(req.params.id!, depth);

    res.json({
      success: true,
      data: connections,
    });
  } catch (error) {
    console.error('Get connections error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get connections',
    });
  }
});

// POST /insights/search - Semantic search
insightsRouter.post('/search', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const validationResult = SearchInsightsSchema.safeParse(req.body);
    if (!validationResult.success) {
      res.status(400).json({
        success: false,
        error: 'Invalid request body',
        details: validationResult.error.errors,
      });
      return;
    }

    const { query, category, startDate, endDate, limit } = validationResult.data;

    const results = await searchInsightsSemantic(query, user.id, {
      category,
      startDate: startDate ? new Date(startDate) : undefined,
      endDate: endDate ? new Date(endDate) : undefined,
      limit,
    });

    res.json({
      success: true,
      data: results,
      query,
    });
  } catch (error) {
    console.error('Search insights error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to search insights',
    });
  }
});

// DELETE /insights/:id - Delete an insight
insightsRouter.delete('/:id', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const { error } = await supabaseAdmin
      .from(Tables.INSIGHT_UNITS)
      .delete()
      .eq('id', req.params.id)
      .eq('user_id', user.id);

    if (error) {
      throw error;
    }

    res.json({
      success: true,
      message: 'Insight deleted',
    });
  } catch (error) {
    console.error('Delete insight error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete insight',
    });
  }
});

// PATCH /insights/:id - Update an insight
insightsRouter.patch('/:id', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const allowedFields = [
      'content',
      'primary_category',
      'secondary_categories',
      'sentiment',
      'emotion_tags',
      'intensity',
    ];

    const updates: Record<string, unknown> = {};
    for (const field of allowedFields) {
      const camelField = field.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
      if (req.body[camelField] !== undefined) {
        updates[field] = req.body[camelField];
      }
    }

    if (Object.keys(updates).length === 0) {
      res.status(400).json({
        success: false,
        error: 'No valid fields to update',
      });
      return;
    }

    const { data, error } = await supabaseAdmin
      .from(Tables.INSIGHT_UNITS)
      .update(updates)
      .eq('id', req.params.id)
      .eq('user_id', user.id)
      .select()
      .single();

    if (error || !data) {
      res.status(404).json({
        success: false,
        error: 'Insight not found or update failed',
      });
      return;
    }

    res.json({
      success: true,
      data: {
        id: data.id,
        content: data.content,
        primaryCategory: data.primary_category,
        secondaryCategories: data.secondary_categories,
        sentiment: data.sentiment,
        emotionTags: data.emotion_tags,
        intensity: data.intensity,
        updatedAt: data.updated_at,
      },
    });
  } catch (error) {
    console.error('Update insight error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update insight',
    });
  }
});

// GET /insights/categories/summary - Get insights grouped by category
insightsRouter.get('/categories/summary', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const daysBack = parseInt(req.query.days as string) || 30;

    const startDate = new Date();
    startDate.setDate(startDate.getDate() - daysBack);

    const { data, error } = await supabaseAdmin
      .from(Tables.INSIGHT_UNITS)
      .select('primary_category')
      .eq('user_id', user.id)
      .gte('insight_date', startDate.toISOString());

    if (error) {
      throw error;
    }

    // Count by category
    const categoryCounts: Record<string, number> = {};
    for (const insight of data || []) {
      const cat = insight.primary_category;
      categoryCounts[cat] = (categoryCounts[cat] || 0) + 1;
    }

    // Get category metadata
    const { data: categories } = await supabaseAdmin
      .from(Tables.CATEGORIES)
      .select('name, display_name, color, icon');

    const summary = Object.entries(categoryCounts)
      .map(([name, count]) => {
        const catMeta = categories?.find((c) => c.name === name);
        return {
          category: name,
          displayName: catMeta?.display_name || name,
          color: catMeta?.color || '#6B7280',
          icon: catMeta?.icon || 'circle',
          count,
        };
      })
      .sort((a, b) => b.count - a.count);

    res.json({
      success: true,
      data: summary,
      period: {
        start: startDate.toISOString(),
        end: new Date().toISOString(),
        days: daysBack,
      },
    });
  } catch (error) {
    console.error('Category summary error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get category summary',
    });
  }
});
