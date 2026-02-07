# Retrospect API

Knowledge Graph API for the Retrospect personal insights system. Extracts atomic insights from various data sources, connects them semantically, and detects patterns over time.

## Features

- **Insight Extraction**: GPT-4 powered extraction of atomic facts from voice recordings, text entries, and other sources
- **Vector Embeddings**: Semantic search using OpenAI's text-embedding-3-small
- **Connection Detection**: Automatic linking of related insights (same topic, causal, temporal, etc.)
- **Pattern Detection**: Daily and weekly cron jobs to find correlations, trends, cycles, and habits
- **Multi-user**: Supports multiple users with Sign in with Apple authentication

## Tech Stack

- **Runtime**: Node.js 18+
- **Framework**: Express.js
- **Database**: Supabase (PostgreSQL with pgvector)
- **AI**: OpenAI GPT-4 + text-embedding-3-small
- **Auth**: JWT with Sign in with Apple
- **Deployment**: Render.com

## API Endpoints

### Authentication
- `POST /auth/signin` - Sign in with Apple
- `POST /auth/refresh` - Refresh JWT token

### Content
- `POST /content` - Upload content for insight extraction
- `GET /content` - List raw content entries
- `GET /content/:id` - Get content details with extracted insights
- `POST /content/:id/reprocess` - Reprocess failed content
- `DELETE /content/:id` - Delete content

### Insights
- `GET /insights` - List insights (with filters)
- `GET /insights/:id` - Get single insight
- `GET /insights/:id/connections` - Get insight connections
- `POST /insights/search` - Semantic search
- `GET /insights/categories/summary` - Category breakdown
- `DELETE /insights/:id` - Delete insight
- `PATCH /insights/:id` - Update insight

### Patterns
- `GET /patterns` - List detected patterns
- `GET /patterns/:id` - Get pattern with supporting insights
- `PUT /patterns/:id/feedback` - Provide feedback on pattern
- `POST /patterns/detect` - Manually trigger pattern detection
- `DELETE /patterns/:id` - Dismiss pattern
- `GET /patterns/stats/summary` - Pattern statistics

### Analytics
- `GET /analytics/summary` - Overall analytics summary
- `GET /analytics/timeline` - Insights over time
- `GET /analytics/emotions` - Emotion tag analysis
- `GET /analytics/connections` - Connection statistics
- `GET /analytics/categories` - Category breakdown

## Setup

### Prerequisites

1. Supabase project with pgvector extension
2. OpenAI API key
3. Node.js 18+

### Local Development

1. Clone the repository
2. Copy `.env.example` to `.env` and fill in values:
   ```bash
   cp .env.example .env
   ```

3. Install dependencies:
   ```bash
   npm install
   ```

4. Run Supabase migrations:
   ```bash
   # Apply migrations to your Supabase project
   supabase db push
   ```

5. Start development server:
   ```bash
   npm run dev
   ```

### Deployment to Render.com

1. Connect your GitHub repository to Render
2. Create a new Web Service using the `render.yaml` blueprint
3. Set environment variables in Render dashboard:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_KEY`
   - `SUPABASE_ANON_KEY`
   - `OPENAI_API_KEY`

## Database Setup

### Supabase Configuration

1. Create a new Supabase project
2. Enable the pgvector extension:
   ```sql
   CREATE EXTENSION IF NOT EXISTS vector;
   ```

3. Run the migrations in order:
   ```
   supabase/migrations/001_initial_schema.sql
   supabase/migrations/002_seed_categories.sql
   ```

4. Apply the vector search functions:
   ```
   supabase/functions/match_insights.sql
   ```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_SERVICE_KEY` | Service role key (bypasses RLS) |
| `SUPABASE_ANON_KEY` | Anonymous key for client auth |
| `OPENAI_API_KEY` | OpenAI API key |
| `JWT_SECRET` | Secret for JWT signing |
| `PORT` | Server port (default: 3000) |
| `NODE_ENV` | Environment (development/production) |

## Content Types

The API supports the following content types for insight extraction:

| Type | Description |
|------|-------------|
| `voice_recording` | Transcribed voice notes |
| `text_entry` | Written journal entries |
| `google_docs` | Google Docs content |
| `healthkit` | Apple HealthKit data |
| `calendar` | Calendar events |
| `twitter_bookmarks` | Twitter/X bookmarks |

Each content type has a tailored GPT-4 extraction prompt optimized for that data source.

## Pattern Types

The system detects five types of patterns:

- **Correlation**: Two factors that tend to occur together
- **Trend**: Directional change over time
- **Cycle**: Repeating patterns
- **Anomaly**: Unusual deviations
- **Habit**: Consistent recurring behaviors

## License

MIT
