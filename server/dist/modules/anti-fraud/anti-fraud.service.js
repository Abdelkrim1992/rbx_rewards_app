import { AntiFraudRepository } from './anti-fraud.repository.js';
import { AuditService } from '../audit/audit.service.js';
import { NotFoundError } from '../../core/app-error.js';
export class AntiFraudService {
    antiFraudRepo;
    auditService;
    constructor(antiFraudRepo = new AntiFraudRepository(), auditService = new AuditService()) {
        this.antiFraudRepo = antiFraudRepo;
        this.auditService = auditService;
    }
    async getAlerts() {
        return this.antiFraudRepo.getAlerts();
    }
    async getFlaggedUsers() {
        return this.antiFraudRepo.getFlaggedUsers();
    }
    async getClusters() {
        return this.antiFraudRepo.getMultiAccountClusters();
    }
    async banUser(dto, adminId, adminEmail) {
        const user = await this.antiFraudRepo.findUserById(dto.userId);
        if (!user) {
            throw new NotFoundError('Target user not found');
        }
        const updated = await this.antiFraudRepo.updateUserBanState(dto.userId, true, dto.reason);
        if (!updated) {
            throw new NotFoundError('Failed to update target user ban status');
        }
        await this.auditService.logAction({
            adminId,
            adminEmail,
            action: 'BAN_USER',
            targetType: 'USER',
            targetId: user.id,
            details: {
                email: user.email,
                reason: dto.reason,
                previousStatus: user.isBanned,
            },
        });
        return updated;
    }
    async unbanUser(dto, adminId, adminEmail) {
        const user = await this.antiFraudRepo.findUserById(dto.userId);
        if (!user) {
            throw new NotFoundError('Target user not found');
        }
        const updated = await this.antiFraudRepo.updateUserBanState(dto.userId, false);
        if (!updated) {
            throw new NotFoundError('Failed to update target user unban status');
        }
        await this.auditService.logAction({
            adminId,
            adminEmail,
            action: 'UNBAN_USER',
            targetType: 'USER',
            targetId: user.id,
            details: { email: user.email },
        });
        return updated;
    }
}
