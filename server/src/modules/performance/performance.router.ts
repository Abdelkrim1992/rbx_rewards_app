import { Router } from 'express';
import { PerformanceController } from './performance.controller.js';
import { jwtAuthGuard } from '../../core/auth.middleware.js';

const router = Router();
const controller = new PerformanceController();

router.use(jwtAuthGuard);
router.get('/telemetry', controller.getTelemetry);
router.post('/purge', controller.purgeCache);
router.post('/ttl', controller.updateTtl);

export const performanceRouter = router;
