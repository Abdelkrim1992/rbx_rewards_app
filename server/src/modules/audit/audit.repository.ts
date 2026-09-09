import crypto from 'node:crypto';
import { db, AuditLogEntity } from '../../database/db.service.js';

export interface CreateAuditLogData {
  adminId: string;
  adminEmail: string;
  action: string;
  targetType: string;
  targetId: string;
  details: Record<string, unknown>;
  ipAddress?: string;
}

export interface PaginationParams {
  take: number;
  skip: number;
}

export class AuditRepository {
  public async createLog(data: CreateAuditLogData): Promise<AuditLogEntity> {
    const log: AuditLogEntity = {
      id: crypto.randomUUID(),
      adminId: data.adminId,
      adminEmail: data.adminEmail,
      action: data.action,
      targetType: data.targetType,
      targetId: data.targetId,
      details: data.details,
      ipAddress: data.ipAddress,
      createdAt: new Date().toISOString(),
    };
    db.auditLogs.unshift(log);
    return log;
  }

  public async getLogs(params: PaginationParams): Promise<{ logs: AuditLogEntity[]; total: number }> {
    const total = db.auditLogs.length;
    const logs = db.auditLogs.slice(params.skip, params.skip + params.take);
    return { logs, total };
  }
}
