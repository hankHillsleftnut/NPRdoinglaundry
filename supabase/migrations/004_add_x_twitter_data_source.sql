-- Add X/Twitter alias integration for bookmark ingestion
INSERT INTO data_sources (name, display_name, description, extraction_prompt, is_active) VALUES
    ('x/twitter', 'X/Twitter', 'Saved X/Twitter bookmarks and threads',
     'Extract atomic insight units from these Twitter bookmarks. Focus on interests, aspirations, values, and topics the user cares about.

RULES:
1. Each insight = ONE atomic observation about user interests/values
2. Identify recurring themes
3. Note emotional resonance (why might they have saved this?)
4. Flag inferences with reasoning
5. Suggest categories based on content themes

OUTPUT: JSON array of insight objects',
     true)
ON CONFLICT (name) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    extraction_prompt = EXCLUDED.extraction_prompt,
    is_active = true;
