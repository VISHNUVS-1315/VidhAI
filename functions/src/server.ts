/**
 * Standalone Node/Express entrypoint (Render free web service, local `npm start`).
 *
 * Root directory: functions
 * Build:          npm install && npm run build
 * Start:          npm start
 * Region/plan:    Singapore / free
 *
 * Listens on process.env.PORT (Render injects it) or 8080.
 * Shows the service name in logs for Render's default logging.
 */

import { ensureFirebaseAdmin } from './config/firebase';
import { logger } from './config/logger';
import { nodeEnv, serverPort, serviceName } from './config/env';
import { app } from './app';

// Initialize Firebase Admin (auto-detects FIREBASE_SERVICE_ACCOUNT_JSON).
ensureFirebaseAdmin();

const port = serverPort();
const server = app.listen(port, '0.0.0.0', () => {
  console.log(`[${serviceName}] listening on 0.0.0.0:${port} (env: ${nodeEnv()})`);
});

// Keep connections alive comfortably above Render's idle proxy timeout.
server.keepAliveTimeout = 65_000;
server.headersTimeout = 70_000;

process.on('uncaughtException', (err) => {
  logger.error('uncaughtException', err);
});
process.on('unhandledRejection', (reason) => {
  logger.error('unhandledRejection', reason);
});