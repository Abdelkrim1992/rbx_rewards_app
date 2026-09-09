import { ComplianceRepository } from './compliance.repository.js';
import { AuditService } from '../audit/audit.service.js';
import { ExecutePurgeDto, ResolveTicketDto } from './dto/compliance.dto.js';
import { NotFoundError } from '../../core/app-error.js';
import { DeletionRequestEntity, SupportTicketEntity } from '../../database/db.service.js';

export interface DeletionWithCountdown extends DeletionRequestEntity {
  daysRemaining: number;
}

export class ComplianceService {
  constructor(
    private readonly repo: ComplianceRepository = new ComplianceRepository(),
    private readonly auditService: AuditService = new AuditService()
  ) {}

  public async getDeletionQueue(): Promise<DeletionWithCountdown[]> {
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

  public async executePurge(dto: ExecutePurgeDto, adminId: string, adminEmail: string): Promise<DeletionRequestEntity> {
    const existing = await this.repo.findDeletionRequestById(dto.requestId);
    if (!existing) throw new NotFoundError('Deletion request not found');

    const completed = await this.repo.executePurge(dto.requestId);
    if (!completed) throw new NotFoundError('Failed to execute purge');

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

  public async getTickets(status?: string): Promise<SupportTicketEntity[]> {
    return this.repo.getSupportTickets(status);
  }

  public async resolveTicket(dto: ResolveTicketDto, adminId: string, adminEmail: string): Promise<SupportTicketEntity> {
    const updated = await this.repo.updateTicketStatus(dto.ticketId, dto.status);
    if (!updated) throw new NotFoundError('Support ticket not found');

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
