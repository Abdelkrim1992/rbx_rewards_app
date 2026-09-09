import { Request, Response, NextFunction } from 'express';
import { PublicService } from './public.service.js';
import { createPublicContactSchema, createPublicDeletionSchema } from './public.dto.js';
import { ValidationError } from '../../core/app-error.js';

export class PublicController {
  constructor(private readonly service: PublicService = new PublicService()) {}

  public getAppConfig = async (_req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const config = this.service.getAppConfig();
      res.status(200).json({ success: true, data: config });
    } catch (err: unknown) {
      next(err);
    }
  };

  public submitContact = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const parseResult = createPublicContactSchema.safeParse(req.body);
      if (!parseResult.success) {
        throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
      }

      const result = this.service.submitContactTicket(parseResult.data);
      res.status(201).json({ success: true, data: result });
    } catch (err: unknown) {
      next(err);
    }
  };

  public submitDeletion = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const parseResult = createPublicDeletionSchema.safeParse(req.body);
      if (!parseResult.success) {
        throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
      }

      const result = this.service.submitDeletionRequest(parseResult.data);
      res.status(201).json({ success: true, data: result });
    } catch (err: unknown) {
      next(err);
    }
  };
}
