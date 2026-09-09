import { Router } from 'express';
import { AuditController } from './audit.controller.js';
import { jwtAuthGuard } from '../../core/auth.middleware.js';

const router = Router();
const controller = new AuditController();

router.get('/', jwtAuthGuard, controller.getLogs);

export const auditRouter = router;
