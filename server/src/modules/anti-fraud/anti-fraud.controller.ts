import { Request, Response, NextFunction } from 'express';
import { AntiFraudService } from './anti-fraud.service.js';
import { banUserSchema, unbanUserSchema } from './dto/fraud-action.dto.js';
import { ValidationError, UnauthorizedError } from '../../core/app-error.js';

export class AntiFraudController {
  constructor(private readonly antiFraudService: AntiFraudService = new AntiFraudService()) {}

  public getAlerts = async (_req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const alerts = await this.antiFraudService.getAlerts();
      res.status(200).json({ success: true, data: alerts });
    } catch (err: unknown) {
      next(err);
    }
  };

  public getFlaggedUsers = async (_req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const users = await this.antiFraudService.getFlaggedUsers();
      res.status(200).json({ success: true, data: users });
    } catch (err: unknown) {
      next(err);
    }
  };

  public getClusters = async (_req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const clusters = await this.antiFraudService.getClusters();
      res.status(200).json({ success: true, data: clusters });
    } catch (err: unknown) {
      next(err);
    }
  };

  public banUser = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.admin) throw new UnauthorizedError();
      const parseResult = banUserSchema.safeParse(req.body);
      if (!parseResult.success) {
        throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
      }

      const updated = await this.antiFraudService.banUser(
        parseResult.data,
        req.admin.adminId,
        req.admin.email
      );
      res.status(200).json({ success: true, data: updated });
    } catch (err: unknown) {
      next(err);
    }
  };

  public unbanUser = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.admin) throw new UnauthorizedError();
      const parseResult = unbanUserSchema.safeParse(req.body);
      if (!parseResult.success) {
        throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
      }

      const updated = await this.antiFraudService.unbanUser(
        parseResult.data,
        req.admin.adminId,
        req.admin.email
      );
      res.status(200).json({ success: true, data: updated });
    } catch (err: unknown) {
      next(err);
    }
  };
}
