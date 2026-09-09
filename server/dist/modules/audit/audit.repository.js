import crypto from 'node:crypto';
import { db } from '../../database/db.service.js';
export class AuditRepository {
    async createLog(data) {
        const log = {
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
    async getLogs(params) {
        const total = db.auditLogs.length;
        const logs = db.auditLogs.slice(params.skip, params.skip + params.take);
        return { logs, total };
    }
}
