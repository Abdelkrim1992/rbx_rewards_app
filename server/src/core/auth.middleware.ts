import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { env } from './env.config.js';
import { UnauthorizedError, ForbiddenError } from './app-error.js';

export interface AdminJwtPayload {
  adminId: string;
  email: string;
  role: 'admin' | 'superadmin';
}

declare global {
  namespace Express {
    interface Request {
      admin?: AdminJwtPayload;
    }
  }
}

function extractBearerToken(authHeader: string | undefined): string {
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new UnauthorizedError('Missing or invalid Authorization header');
  }
  const token = authHeader.substring(7).trim();
  if (!token) {
    throw new UnauthorizedError('Empty Bearer token provided');
  }
  return token;
}

export function jwtAuthGuard(req: Request, _res: Response, next: NextFunction): void {
  try {
    const token = extractBearerToken(req.headers.authorization);
    const decoded = jwt.verify(token, env.JWT_SECRET) as unknown;

    if (typeof decoded !== 'object' || decoded === null) {
      throw new UnauthorizedError('Invalid token structure');
    }

    const payload = decoded as Record<string, unknown>;
    if (typeof payload['adminId'] !== 'string' || typeof payload['email'] !== 'string' || typeof payload['role'] !== 'string') {
      throw new UnauthorizedError('Malformed JWT claims');
    }

    req.admin = {
      adminId: payload['adminId'],
      email: payload['email'],
      role: payload['role'] === 'superadmin' ? 'superadmin' : 'admin',
    };

    next();
  } catch (err: unknown) {
    if (err instanceof UnauthorizedError) {
      next(err);
      return;
    }
    next(new UnauthorizedError('Token is invalid or expired'));
  }
}

export function roleGuard(requiredRole: 'admin' | 'superadmin') {
  return (req: Request, _res: Response, next: NextFunction): void => {
    if (!req.admin) {
      next(new UnauthorizedError('Authentication required'));
      return;
    }
    if (requiredRole === 'superadmin' && req.admin.role !== 'superadmin') {
      next(new ForbiddenError('Insufficient administrative privileges'));
      return;
    }
    next();
  };
}
