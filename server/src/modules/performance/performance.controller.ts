import { Request, Response, NextFunction } from 'express';
import { PerformanceService } from './performance.service.js';
import { purgeCacheSchema, updateTtlSchema } from './dto/purge-cache.dto.js';
import { ValidationError, UnauthorizedError } from '../../core/app-error.js';

export class PerformanceController {
  constructor(private readonly service: PerformanceService = new PerformanceService()) {}

  public getTelemetry = async (_req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const data = await this.service.getTelemetry();
      res.status(200).json({ success: true, data });
    } catch (err: unknown) {
      next(err);
    }
  };

  public purgeCache = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.admin) throw new UnauthorizedError();
      const parseResult = purgeCacheSchema.safeParse(req.body);
      if (!parseResult.success) {
        throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
      }

      const result = await this.service.purge(
        parseResult.data,
        req.admin.adminId,
        req.admin.email
      );
      res.status(200).json({ success: true, data: result });
    } catch (err: unknown) {
      next(err);
    }
  };

  public updateTtl = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.admin) throw new UnauthorizedError();
      const parseResult = updateTtlSchema.safeParse(req.body);
      if (!parseResult.success) {
        throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
      }

      const result = await this.service.updateTtl(
        parseResult.data,
        req.admin.adminId,
        req.admin.email
      );
      res.status(200).json({ success: true, data: result });
    } catch (err: unknown) {
      next(err);
    }
  };
}
