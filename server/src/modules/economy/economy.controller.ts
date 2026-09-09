import { Request, Response, NextFunction } from 'express';
import { EconomyService } from './economy.service.js';
import { updateMiniGameCapsSchema, updateGlobalCapSchema } from './dto/update-caps.dto.js';
import { updateRewardCardSchema } from './dto/update-pricing.dto.js';
import { ValidationError, UnauthorizedError } from '../../core/app-error.js';

export class EconomyController {
  constructor(private readonly service: EconomyService = new EconomyService()) {}

  public getConfigs = async (_req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const data = await this.service.getAllEconomyConfigs();
      res.status(200).json({ success: true, data });
    } catch (err: unknown) {
      next(err);
    }
  };

  public updateCaps = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.admin) throw new UnauthorizedError();
      const parseResult = updateMiniGameCapsSchema.safeParse(req.body);
      if (!parseResult.success) {
        throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
      }

      const result = await this.service.updateMiniGameCaps(
        parseResult.data,
        req.admin.adminId,
        req.admin.email
      );
      res.status(200).json({ success: true, data: result });
    } catch (err: unknown) {
      next(err);
    }
  };

  public updateGlobalCap = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.admin) throw new UnauthorizedError();
      const parseResult = updateGlobalCapSchema.safeParse(req.body);
      if (!parseResult.success) {
        throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
      }

      const result = await this.service.updateGlobalCap(
        parseResult.data,
        req.admin.adminId,
        req.admin.email
      );
      res.status(200).json({ success: true, data: result });
    } catch (err: unknown) {
      next(err);
    }
  };

  public updateCard = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.admin) throw new UnauthorizedError();
      const parseResult = updateRewardCardSchema.safeParse(req.body);
      if (!parseResult.success) {
        throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
      }

      const result = await this.service.updateRewardCard(
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
