import { Request, Response, NextFunction } from 'express';
import { ComplianceService } from './compliance.service.js';
import { executePurgeSchema, resolveTicketSchema } from './dto/compliance.dto.js';
import { ValidationError, UnauthorizedError } from '../../core/app-error.js';

export class ComplianceController {
  constructor(private readonly service: ComplianceService = new ComplianceService()) {}

  public getDeletionQueue = async (_req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const data = await this.service.getDeletionQueue();
      res.status(200).json({ success: true, data });
    } catch (err: unknown) {
      next(err);
    }
  };

  public executePurge = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.admin) throw new UnauthorizedError();
      const parseResult = executePurgeSchema.safeParse(req.body);
      if (!parseResult.success) {
        throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
      }

      const result = await this.service.executePurge(
        parseResult.data,
        req.admin.adminId,
        req.admin.email
      );
      res.status(200).json({ success: true, data: result });
    } catch (err: unknown) {
      next(err);
    }
  };

  public getTickets = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const status = req.query['status'] as string | undefined;
      const data = await this.service.getTickets(status);
      res.status(200).json({ success: true, data });
    } catch (err: unknown) {
      next(err);
    }
  };

  public resolveTicket = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.admin) throw new UnauthorizedError();
      const parseResult = resolveTicketSchema.safeParse(req.body);
      if (!parseResult.success) {
        throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
      }

      const result = await this.service.resolveTicket(
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
