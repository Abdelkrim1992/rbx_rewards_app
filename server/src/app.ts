import express, { Express } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { authRouter } from './modules/auth/auth.router.js';
import { antiFraudRouter } from './modules/anti-fraud/anti-fraud.router.js';
import { redemptionsRouter } from './modules/redemptions/redemptions.router.js';
import { economyRouter } from './modules/economy/economy.router.js';
import { performanceRouter } from './modules/performance/performance.router.js';
import { complianceRouter } from './modules/compliance/compliance.router.js';
import { auditRouter } from './modules/audit/audit.router.js';
import { publicRouter } from './modules/public/public.router.js';
import { errorHandler } from './core/error-handler.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export function createApp(): Express {
  const app = express();

  // Basic Security & Parsing
  app.use(
    helmet({
      contentSecurityPolicy: false, // Allow inline styles/scripts for internal admin SPA
      crossOriginEmbedderPolicy: false,
    })
  );
  app.use(cors({ origin: true, credentials: true }));
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));

  // Health endpoint for Playwright webServer and container probes
  app.get('/health', (_req, res) => {
    res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
  });

  // Test fixture reset endpoint for Playwright E2E isolation
  app.post('/api/v1/test-reset', async (_req, res) => {
    const { db } = await import('./database/db.service.js');
    db.reset();
    res.status(200).json({ success: true, message: 'Database reset to initial fixtures' });
  });

  // REST API v1 routes
  app.use('/api/v1/public', publicRouter);
  app.use('/api/v1/auth', authRouter);
  app.use('/api/v1/anti-fraud', antiFraudRouter);
  app.use('/api/v1/redemptions', redemptionsRouter);
  app.use('/api/v1/economy', economyRouter);
  app.use('/api/v1/performance', performanceRouter);
  app.use('/api/v1/compliance', complianceRouter);
  app.use('/api/v1/audit', auditRouter);

  // Serve Static Frontend Portals
  const websiteAdminPath = path.resolve(__dirname, '../../website/admin');
  const websitePath = path.resolve(__dirname, '../../website');

  app.use('/admin', express.static(websiteAdminPath));
  app.use('/', express.static(websitePath));

  // Global Error Handler
  app.use(errorHandler);

  return app;
}
