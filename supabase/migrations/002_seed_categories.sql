-- Seed Categories Migration
-- 15 top-level categories for the knowledge graph

INSERT INTO categories (name, display_name, description, color, icon, sort_order) VALUES
    ('sleep', 'Sleep', 'Sleep quality, duration, patterns, and related issues', '#6366F1', 'moon.fill', 1),
    ('health', 'Health', 'Physical health, symptoms, medical appointments, and wellness', '#10B981', 'heart.fill', 2),
    ('mental_health', 'Mental Health', 'Emotional wellbeing, therapy, coping strategies', '#8B5CF6', 'brain.head.profile', 3),
    ('work', 'Work', 'Job tasks, projects, meetings, career development', '#F59E0B', 'briefcase.fill', 4),
    ('relationships', 'Relationships', 'Family, friends, romantic partners, social interactions', '#EC4899', 'person.2.fill', 5),
    ('productivity', 'Productivity', 'Task management, focus, efficiency, time management', '#3B82F6', 'checkmark.circle.fill', 6),
    ('finance', 'Finance', 'Money, budgeting, investments, expenses', '#059669', 'dollarsign.circle.fill', 7),
    ('creativity', 'Creativity', 'Art, writing, music, creative projects and ideas', '#F97316', 'paintbrush.fill', 8),
    ('learning', 'Learning', 'Education, skills development, courses, reading', '#14B8A6', 'book.fill', 9),
    ('fitness', 'Fitness', 'Exercise, workouts, physical activity, sports', '#EF4444', 'figure.run', 10),
    ('nutrition', 'Nutrition', 'Diet, meals, eating habits, supplements', '#84CC16', 'fork.knife', 11),
    ('spirituality', 'Spirituality', 'Meditation, mindfulness, beliefs, personal growth', '#A855F7', 'sparkles', 12),
    ('hobbies', 'Hobbies', 'Leisure activities, interests, personal projects', '#06B6D4', 'star.fill', 13),
    ('travel', 'Travel', 'Trips, vacations, commuting, places visited', '#0EA5E9', 'airplane', 14),
    ('home', 'Home', 'Living space, household tasks, family life at home', '#78716C', 'house.fill', 15)
ON CONFLICT (name) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    color = EXCLUDED.color,
    icon = EXCLUDED.icon,
    sort_order = EXCLUDED.sort_order;

-- Seed Data Sources
INSERT INTO data_sources (name, display_name, description, extraction_prompt) VALUES
    ('voice_recording', 'Voice Recording', 'Transcribed voice notes and audio journals',
     'Extract atomic insight units from this voice transcript. The user is speaking stream-of-consciousness, so look for emotional undertones, implied states, and both explicit and inferred insights.

RULES:
1. Each insight = ONE atomic fact (not compound statements)
2. Flag inferences with reasoning (is_inferred: true + inference_reasoning)
3. Include temporal context when mentioned
4. Rate sentiment (positive/negative/neutral/mixed) and intensity (1-10)
5. Identify emotion tags when present (anxious, happy, frustrated, excited, etc.)
6. Suggest primary_category and secondary_categories from: sleep, health, mental_health, work, relationships, productivity, finance, creativity, learning, fitness, nutrition, spirituality, hobbies, travel, home

OUTPUT: JSON array of insight objects'),

    ('text_entry', 'Text Entry', 'Written journal entries and notes',
     'Extract atomic insight units from this written journal entry. Look for structured thoughts, reflections, and explicit statements.

RULES:
1. Each insight = ONE atomic fact (not compound statements)
2. Flag inferences with reasoning
3. Include temporal context
4. Rate sentiment and intensity
5. Identify emotion tags
6. Suggest categories

OUTPUT: JSON array of insight objects'),

    ('google_docs', 'Google Docs', 'Documents from Google Drive',
     'Extract atomic insight units from this Google Doc. Focus on work content, project progress, decisions made, and any personal reflections.

RULES:
1. Each insight = ONE atomic fact
2. Prioritize actionable items and decisions
3. Note project status and blockers
4. Flag inferences with reasoning
5. Suggest categories (likely work, productivity, learning)

OUTPUT: JSON array of insight objects'),

    ('healthkit', 'Apple HealthKit', 'Health and fitness data from Apple Health',
     'Extract atomic insight units from this HealthKit data. Focus on meaningful deviations from baseline, trends, and health-relevant patterns.

RULES:
1. Each insight = ONE atomic observation
2. Compare to typical values when available
3. Flag significant deviations
4. Note correlations with time of day or week
5. Suggest categories (health, fitness, sleep, nutrition)

OUTPUT: JSON array of insight objects'),

    ('calendar', 'Calendar', 'Calendar events and schedule data',
     'Extract atomic insight units from this calendar data. Focus on priorities, stress indicators, work-life balance, and scheduling patterns.

RULES:
1. Each insight = ONE atomic observation
2. Note meeting density and type distribution
3. Identify potential stress points (back-to-back meetings, long days)
4. Observe work-life balance indicators
5. Suggest categories (work, relationships, hobbies, etc.)

OUTPUT: JSON array of insight objects'),

    ('twitter_bookmarks', 'Twitter Bookmarks', 'Saved tweets and threads',
     'Extract atomic insight units from these Twitter bookmarks. Focus on interests, aspirations, values, and topics the user cares about.

RULES:
1. Each insight = ONE atomic observation about user interests/values
2. Identify recurring themes
3. Note emotional resonance (why might they have saved this?)
4. Flag inferences with reasoning
5. Suggest categories based on content themes

OUTPUT: JSON array of insight objects')
ON CONFLICT (name) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    extraction_prompt = EXCLUDED.extraction_prompt;
