import './services/telemetry.js';
import { createApp } from './app.js';
import { config } from './utils/config.js';
import { supabaseUserLookup } from './middleware/auth.js';
import { applyServerTimeouts } from './server-settings.js';
import { createAgentDoorClient } from './doors/agent.js';

/** The real server: real dependencies, then listen. `npm start` reaches this through index.ts. */
const app = createApp({
  agent: createAgentDoorClient({ baseUrl: config.agent.serviceUrl, internalSecret: config.agent.internalSecret }),
  now: Date.now,
  users: supabaseUserLookup,
});

console.log('Legacy backend crons are disabled. Agent crons own ingestion and podcasts.');

const server = app.listen(config.server.port, () => {
  console.log(`Server running on port ${config.server.port}`);
  console.log(`Environment: ${config.server.nodeEnv}`);
});

applyServerTimeouts(server);

export default app;
