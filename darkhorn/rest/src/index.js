const express = require('express');
const morgan = require('morgan');
const { getConfig } = require('./config');
const { initKeys } = require('./auth/keys');
const authMiddleware = require('./auth/middleware');
const oidcRouter = require('./auth/oidc');
const usersRouter = require('./routes/users');
const passwordsRouter = require('./routes/passwords');
const groupsRouter = require('./routes/groups');
const errorHandler = require('./middleware/errorHandler');

async function main() {
  const cfg = getConfig();
  const app = express();

  // ── Body parsing ────────────────────────────────────────────────────────────
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));

  // ── Logging ─────────────────────────────────────────────────────────────────
  app.use(morgan(cfg.logging.level));

  // ── Init OIDC keypair ────────────────────────────────────────────────────────
  await initKeys();
  console.log('[OIDC] RS256 keypair ready');

  // ── Public OIDC routes (no auth required) ───────────────────────────────────
  app.use(oidcRouter);

  // ── Public routes (no auth) ──────────────────────────────────────────────────
  app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
  });

  // ── Auth middleware for all /api routes ──────────────────────────────────────
  app.use('/api', authMiddleware);

  // ── API routes ───────────────────────────────────────────────────────────────
  app.use('/api', usersRouter);
  app.use('/api', passwordsRouter);
  app.use('/api', groupsRouter);

  // ── 404 handler ──────────────────────────────────────────────────────────────
  app.use((req, res) => {
    res.status(404).json({ error: 'not_found', message: `Route ${req.method} ${req.path} not found.` });
  });

  // ── Error handler ─────────────────────────────────────────────────────────────
  app.use(errorHandler);

  // ── Start ─────────────────────────────────────────────────────────────────────
  const { host, port } = cfg.server;
  app.listen(port, host, () => {
    console.log(`[SERVER] darkhorn running at http://${host}:${port}`);
    console.log(`[SERVER] OIDC discovery: http://${host}:${port}/.well-known/openid-configuration`);
    console.log(`[SERVER] Health check:   http://${host}:${port}/api/health`);
  });
}

main().catch(err => {
  console.error('[FATAL]', err);
  process.exit(1);
});
