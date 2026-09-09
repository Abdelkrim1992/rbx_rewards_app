import { AuditRepository, CreateAuditLogData, PaginationParams } from './audit.repository.js';
import { AuditLogEntity } from '../../database/db.service.js';

export class AuditService {
  constructor(private readonly auditRepo: AuditRepository = new AuditRepository()) {}

  public async logAction(data: CreateAuditLogData): Promise<AuditLogEntity> {
    return this.auditRepo.createLog(data);
  }

  public async getAuditTrail(params: PaginationParams): Promise<{ logs: AuditLogEntity[]; total: number }> {
    const take = Math.min(Math.max(params.take || 20, 1), 100);
    const skip = Math.max(params.skip || 0, 0);
    return this.auditRepo.getLogs({ take, skip });
  }
}
