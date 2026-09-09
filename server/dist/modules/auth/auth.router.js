import { Router } from 'express';
import { AuthController } from './auth.controller.js';
import { jwtAuthGuard } from '../../core/auth.middleware.js';
const router = Router();
const controller = new AuthController();
router.post('/login', controller.login);
router.get('/session', jwtAuthGuard, controller.getSession);
export const authRouter = router;
