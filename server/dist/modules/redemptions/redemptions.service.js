import { RedemptionsRepository } from './redemptions.repository.js';
import { AuditService } from '../audit/audit.service.js';
import { NotFoundError, ValidationError } from '../../core/app-error.js';
export class RedemptionsService {
    repo;
    auditService;
    constructor(repo = new RedemptionsRepository(), auditService = new AuditService()) {
        this.repo = repo;
        this.auditService = auditService;
    }
    async getList(params) {
        const { items, total } = await this.repo.getRedemptions(params);
        const now = Date.now();
        const itemsWithSla = items.map((r) => {
            const requestedTime = new Date(r.requestedAt).getTime();
            const elapsedHours = (now - requestedTime) / (1000 * 60 * 60);
            const slaHoursRemaining = Math.max(0, Math.round((48 - elapsedHours) * 10) / 10);
            return {
                ...r,
                slaHoursRemaining,
                isSlaBreached: elapsedHours > 48,
            };
        });
        return { items: itemsWithSla, total };
    }
    async dispatchPin(dto, adminId, adminEmail) {
        const existing = await this.repo.findById(dto.redemptionId);
        if (!existing)
            throw new NotFoundError('Redemption request not found');
        if (existing.status !== 'pending')
            throw new ValidationError('Only pending requests can be dispatched');
        const updated = await this.repo.fulfill(dto.redemptionId, dto.pinCode, dto.adminNotes);
        if (!updated)
            throw new NotFoundError('Failed to update redemption');
        await this.auditService.logAction({
            adminId,
            adminEmail,
            action: 'DISPATCH_PIN',
            targetType: 'REDEMPTION',
            targetId: updated.id,
            details: {
                userId: updated.userId,
                denomination: updated.denomination,
                cost: updated.cost,
            },
        });
        return updated;
    }
    async rejectReward(dto, adminId, adminEmail) {
        const existing = await this.repo.findById(dto.redemptionId);
        if (!existing)
            throw new NotFoundError('Redemption request not found');
        if (existing.status !== 'pending')
            throw new ValidationError('Only pending requests can be rejected');
        const updated = await this.repo.reject(dto.redemptionId, dto.reason);
        if (!updated)
            throw new NotFoundError('Failed to reject redemption');
        await this.auditService.logAction({
            adminId,
            adminEmail,
            action: 'REJECT_REWARD',
            targetType: 'REDEMPTION',
            targetId: updated.id,
            details: {
                userId: updated.userId,
                reason: dto.reason,
                refundedCoins: updated.cost,
            },
        });
        return updated;
    }
}
