import { AuditRepository } from './audit.repository.js';
export class AuditService {
    auditRepo;
    constructor(auditRepo = new AuditRepository()) {
        this.auditRepo = auditRepo;
    }
    async logAction(data) {
        return this.auditRepo.createLog(data);
    }
    async getAuditTrail(params) {
        const take = Math.min(Math.max(params.take || 20, 1), 100);
        const skip = Math.max(params.skip || 0, 0);
        return this.auditRepo.getLogs({ take, skip });
    }
}
