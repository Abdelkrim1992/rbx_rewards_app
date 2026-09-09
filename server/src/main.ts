import { createApp } from './app.js';
import { env } from './core/env.config.js';

const app = createApp();

const server = app.listen(env.PORT, () => {
  console.log(`[RBX Admin Server] Running at http://127.0.0.1:${env.PORT}`);
  console.log(`[Admin Portal] Available at http://127.0.0.1:${env.PORT}/admin/`);
  console.log(`[Public Portal] Available at http://127.0.0.1:${env.PORT}/`);
});

process.on('SIGTERM', () => {
  console.log('[RBX Admin Server] Received SIGTERM, shutting down gracefully...');
  server.close(() => {
    process.exit(0);
  });
});
