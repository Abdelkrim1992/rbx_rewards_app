import { ComplianceRepository } from './compliance.repository.js';
import { AuditService } from '../audit/audit.service.js';
import { NotFoundError } from '../../core/app-error.js';
export class ComplianceService {
    repo;
    auditService;
    constructor(repo = new ComplianceRepository(), auditService = new AuditService()) {
        this.repo = repo;
        this.auditService = auditService;
    }
    async getDeletionQueue() {
        const list = await this.repo.getDeletionRequests();
        const now = Date.now();
        return list.map((item) => {
            const scheduledTime = new Date(item.scheduledPurgeAt).getTime();
            const diffMs = Math.max(0, scheduledTime - now);
            const daysRemaining = Math.ceil(diffMs / (1000 * 60 * 60 * 24));
            return {
                ...item,
                daysRemaining,
            };
        });
    }
    async executePurge(dto, adminId, adminEmail) {
        const existing = await this.repo.findDeletionRequestById(dto.requestId);
        if (!existing)
            throw new NotFoundError('Deletion request not found');
        const completed = await this.repo.executePurge(dto.requestId);
        if (!completed)
            throw new NotFoundError('Failed to execute purge');
        await this.auditService.logAction({
            adminId,
            adminEmail,
            action: 'EXECUTE_DATA_PURGE',
            targetType: 'DELETION_REQUEST',
            targetId: completed.id,
            details: { email: completed.email, userId: completed.userId },
        });
        return completed;
    }
    async getTickets(status) {
        return this.repo.getSupportTickets(status);
    }
    async resolveTicket(dto, adminId, adminEmail) {
        const updated = await this.repo.updateTicketStatus(dto.ticketId, dto.status);
        if (!updated)
            throw new NotFoundError('Support ticket not found');
        await this.auditService.logAction({
            adminId,
            adminEmail,
            action: 'UPDATE_TICKET_STATUS',
            targetType: 'SUPPORT_TICKET',
            targetId: updated.id,
            details: { status: dto.status, subject: updated.subject },
        });
        return updated;
    }
}
