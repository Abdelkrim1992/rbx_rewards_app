import { Router } from 'express';
import { PublicController } from './public.controller.js';

const router = Router();
const controller = new PublicController();

router.get('/app-config', controller.getAppConfig);
router.post('/contact', controller.submitContact);
router.post('/deletion-request', controller.submitDeletion);

export const publicRouter = router;
