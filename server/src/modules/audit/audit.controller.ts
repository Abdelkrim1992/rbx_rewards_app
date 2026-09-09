import { Request, Response, NextFunction } from 'express';
import { AuditService } from './audit.service.js';

export class AuditController {
  constructor(private readonly auditService: AuditService = new AuditService()) {}

  public getLogs = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const take = parseInt((req.query['take'] as string) || '20', 10);
      const skip = parseInt((req.query['skip'] as string) || '0', 10);

      const result = await this.auditService.getAuditTrail({ take, skip });
      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err: unknown) {
      next(err);
    }
  };
}
