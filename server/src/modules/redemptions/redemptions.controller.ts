import { Request, Response, NextFunction } from 'express';
import { RedemptionsService } from './redemptions.service.js';
import { dispatchPinSchema } from './dto/dispatch-pin.dto.js';
import { rejectRewardSchema } from './dto/reject-reward.dto.js';
import { ValidationError, UnauthorizedError } from '../../core/app-error.js';

export class RedemptionsController {
  constructor(private readonly service: RedemptionsService = new RedemptionsService()) {}

  public getRedemptions = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const status = req.query['status'] as 'pending' | 'fulfilled' | 'rejected' | 'all' | undefined;
      const take = parseInt((req.query['take'] as string) || '20', 10);
      const skip = parseInt((req.query['skip'] as string) || '0', 10);

      const result = await this.service.getList({ status, take, skip });
      res.status(200).json({ success: true, data: result });
    } catch (err: unknown) {
      next(err);
    }
  };

  public dispatchPin = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.admin) throw new UnauthorizedError();
      const parseResult = dispatchPinSchema.safeParse(req.body);
      if (!parseResult.success) {
        throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
      }

      const result = await this.service.dispatchPin(
        parseResult.data,
        req.admin.adminId,
        req.admin.email
      );
      res.status(200).json({ success: true, data: result });
    } catch (err: unknown) {
      next(err);
    }
  };

  public rejectReward = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.admin) throw new UnauthorizedError();
      const parseResult = rejectRewardSchema.safeParse(req.body);
      if (!parseResult.success) {
        throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
      }

      const result = await this.service.rejectReward(
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
