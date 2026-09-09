import { Router } from 'express';
import { EconomyController } from './economy.controller.js';
import { jwtAuthGuard } from '../../core/auth.middleware.js';

const router = Router();
const controller = new EconomyController();

router.use(jwtAuthGuard);
router.get('/', controller.getConfigs);
router.post('/caps', controller.updateCaps);
router.post('/global-cap', controller.updateGlobalCap);
router.post('/card', controller.updateCard);

export const economyRouter = router;
