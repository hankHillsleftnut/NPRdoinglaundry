import { Router, Request, Response } from 'express';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import type { AnalyticsSummary, Category, Sentiment } from '../types/index.js';

export const analyticsRouter = Router();

// GET /analytics/summary - Get overall analytics summary
analyticsRouter.get('/summary', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const daysBack = parseInt(req.query.days as string) || 30;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - daysBack);

    // Use the database function for stats
    const { data: stats, error: statsError } = await supabaseAdmin.rpc(
      'get_user_stats',
      {
        p_user_id: user.id,
        p_days_back: daysBack,
      }
    );

    if (statsError) {
      throw statsError;
    }

    const statsRow = Array.isArray(stats) ? stats[0] : stats;

    const summary: AnalyticsSummary = {
      totalInsights: Number(statsRow?.total_insights) || 0,
      insightsByCategory: (statsRow?.insights_by_category as Record<Category, number>) || {},
      sentimentDistribution:
        (statsRow?.sentiment_distribution as Record<Sentiment | 'unknown', number>) || {},
      averageIntensity: statsRow?.avg_intensity
        ? Number(statsRow.avg_intensity)
        : null,
      inferredRatio: statsRow?.inferred_ratio
        ? Number(statsRow.inferred_ratio)
        : 0,
      totalPatterns: Number(statsRow?.total_patterns) || 0,
      activePatterns: Number(statsRow?.active_patterns) || 0,
      periodStart: startDate.toISOString(),
      periodEnd: new Date().toISOString(),
    };

    res.json({
      success: true,
      data: summary,
    });
  } catch (error) {
    console.error('Analytics summary error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get analytics summary',
    });
  }
});

// GET /analytics/timeline - Get insights over time
analyticsRouter.get('/timeline', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const daysBack = parseInt(req.query.days as string) || 30;
    const groupBy = (req.query.groupBy as string) || 'day';
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - daysBack);

    const { data: insights, error } = await supabaseAdmin
      .from(Tables.INSIGHT_UNITS)
      .select('insight_date, primary_category, sentiment')
      .eq('user_id', user.id)
      .gte('insight_date', startDate.toISOString())
      .order('insight_date', { ascending: true });

    if (error) {
      throw error;
    }

    // Group by date
    const timeline: Record<
      string,
      { count: number; categories: Record<string, number>; sentiment: Record<string, number> }
    > = {};

    for (const insight of insights || []) {
      const date = new Date(insight.insight_date);
      let key: string;

      if (groupBy === 'week') {
        // Get start of week
        const weekStart = new Date(date);
        weekStart.setDate(date.getDate() - date.getDay());
        key = weekStart.toISOString().split('T')[0] || '';
      } else {
        key = date.toISOString().split('T')[0] || '';
      }

      if (!timeline[key]) {
        timeline[key] = { count: 0, categories: {}, sentiment: {} };
      }

      const entry = timeline[key];
      if (entry) {
        entry.count++;
        const cat = insight.primary_category;
        entry.categories[cat] = (entry.categories[cat] || 0) + 1;

        const sent = insight.sentiment || 'unknown';
        entry.sentiment[sent] = (entry.sentiment[sent] || 0) + 1;
      }
    }

    const timelineArray = Object.entries(timeline)
      .map(([date, data]) => ({
        date,
        ...data,
      }))
      .sort((a, b) => a.date.localeCompare(b.date));

    res.json({
      success: true,
      data: timelineArray,
      period: {
        start: startDate.toISOString(),
        end: new Date().toISOString(),
        groupBy,
      },
    });
  } catch (error) {
    console.error('Analytics timeline error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get analytics timeline',
    });
  }
});

// GET /analytics/emotions - Get emotion tag analysis
analyticsRouter.get('/emotions', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const daysBack = parseInt(req.query.days as string) || 30;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - daysBack);

    const { data: insights, error } = await supabaseAdmin
      .from(Tables.INSIGHT_UNITS)
      .select('emotion_tags, intensity')
      .eq('user_id', user.id)
      .gte('insight_date', startDate.toISOString());

    if (error) {
      throw error;
    }

    const emotionCounts: Record<string, { count: number; totalIntensity: number }> = {};

    for (const insight of insights || []) {
      for (const emotion of insight.emotion_tags || []) {
        if (!emotionCounts[emotion]) {
          emotionCounts[emotion] = { count: 0, totalIntensity: 0 };
        }
        const entry = emotionCounts[emotion];
        if (entry) {
          entry.count++;
          if (insight.intensity) {
            entry.totalIntensity += insight.intensity;
          }
        }
      }
    }

    const emotions = Object.entries(emotionCounts)
      .map(([emotion, data]) => ({
        emotion,
        count: data.count,
        averageIntensity:
          data.count > 0 ? data.totalIntensity / data.count : null,
      }))
      .sort((a, b) => b.count - a.count);

    res.json({
      success: true,
      data: emotions,
    });
  } catch (error) {
    console.error('Analytics emotions error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get emotion analysis',
    });
  }
});

// GET /analytics/connections - Get connection statistics
analyticsRouter.get('/connections', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    // Get all insight IDs for the user
    const { data: userInsights, error: insightsError } = await supabaseAdmin
      .from(Tables.INSIGHT_UNITS)
      .select('id')
      .eq('user_id', user.id);

    if (insightsError) {
      throw insightsError;
    }

    const insightIds = (userInsights || []).map((i) => i.id);

    if (insightIds.length === 0) {
      res.json({
        success: true,
        data: {
          totalConnections: 0,
          byType: {},
          averageStrength: null,
        },
      });
      return;
    }

    // Get connections where source is user's insight
    const { data: connections, error: connError } = await supabaseAdmin
      .from(Tables.INSIGHT_CONNECTIONS)
      .select('connection_type, strength')
      .in('source_insight_id', insightIds);

    if (connError) {
      throw connError;
    }

    const byType: Record<string, number> = {};
    let totalStrength = 0;

    for (const conn of connections || []) {
      const type = conn.connection_type;
      byType[type] = (byType[type] || 0) + 1;
      totalStrength += conn.strength;
    }

    res.json({
      success: true,
      data: {
        totalConnections: connections?.length || 0,
        byType,
        averageStrength:
          connections && connections.length > 0
            ? totalStrength / connections.length
            : null,
      },
    });
  } catch (error) {
    console.error('Analytics connections error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get connection statistics',
    });
  }
});

// GET /analytics/categories - Get category breakdown
analyticsRouter.get('/categories', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const daysBack = parseInt(req.query.days as string) || 30;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - daysBack);

    const { data: insights, error } = await supabaseAdmin
      .from(Tables.INSIGHT_UNITS)
      .select('primary_category, secondary_categories, sentiment, intensity')
      .eq('user_id', user.id)
      .gte('insight_date', startDate.toISOString());

    if (error) {
      throw error;
    }

    const categoryStats: Record<
      string,
      {
        count: number;
        asSecondary: number;
        sentimentBreakdown: Record<string, number>;
        totalIntensity: number;
      }
    > = {};

    for (const insight of insights || []) {
      const primary = insight.primary_category;

      if (!categoryStats[primary]) {
        categoryStats[primary] = {
          count: 0,
          asSecondary: 0,
          sentimentBreakdown: {},
          totalIntensity: 0,
        };
      }

      const stats = categoryStats[primary];
      if (stats) {
        stats.count++;
        const sent = insight.sentiment || 'unknown';
        stats.sentimentBreakdown[sent] = (stats.sentimentBreakdown[sent] || 0) + 1;
        if (insight.intensity) {
          stats.totalIntensity += insight.intensity;
        }
      }

      // Count secondary categories
      for (const secondary of insight.secondary_categories || []) {
        if (!categoryStats[secondary]) {
          categoryStats[secondary] = {
            count: 0,
            asSecondary: 0,
            sentimentBreakdown: {},
            totalIntensity: 0,
          };
        }
        const secStats = categoryStats[secondary];
        if (secStats) {
          secStats.asSecondary++;
        }
      }
    }

    // Get category metadata
    const { data: categories } = await supabaseAdmin
      .from(Tables.CATEGORIES)
      .select('name, display_name, color, icon');

    const categoryBreakdown = Object.entries(categoryStats)
      .map(([name, stats]) => {
        const catMeta = categories?.find((c) => c.name === name);
        return {
          category: name,
          displayName: catMeta?.display_name || name,
          color: catMeta?.color || '#6B7280',
          icon: catMeta?.icon || 'circle',
          primaryCount: stats.count,
          secondaryCount: stats.asSecondary,
          totalMentions: stats.count + stats.asSecondary,
          sentimentBreakdown: stats.sentimentBreakdown,
          averageIntensity:
            stats.count > 0 ? stats.totalIntensity / stats.count : null,
        };
      })
      .sort((a, b) => b.totalMentions - a.totalMentions);

    res.json({
      success: true,
      data: categoryBreakdown,
    });
  } catch (error) {
    console.error('Analytics categories error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get category breakdown',
    });
  }
});
