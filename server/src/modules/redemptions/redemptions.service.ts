import { RedemptionsRepository, RedemptionFilterParams } from './redemptions.repository.js';
import { AuditService } from '../audit/audit.service.js';
import { DispatchPinDto } from './dto/dispatch-pin.dto.js';
import { RejectRewardDto } from './dto/reject-reward.dto.js';
import { NotFoundError, ValidationError } from '../../core/app-error.js';
import { RedemptionEntity } from '../../database/db.service.js';

export interface RedemptionWithSla extends RedemptionEntity {
  slaHoursRemaining: number;
  isSlaBreached: boolean;
}

export class RedemptionsService {
  constructor(
    private readonly repo: RedemptionsRepository = new RedemptionsRepository(),
    private readonly auditService: AuditService = new AuditService()
  ) {}

  public async getList(params: RedemptionFilterParams): Promise<{ items: RedemptionWithSla[]; total: number }> {
    const { items, total } = await this.repo.getRedemptions(params);
    const now = Date.now();

    const itemsWithSla: RedemptionWithSla[] = items.map((r) => {
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

  public async dispatchPin(dto: DispatchPinDto, adminId: string, adminEmail: string): Promise<RedemptionEntity> {
    const existing = await this.repo.findById(dto.redemptionId);
    if (!existing) throw new NotFoundError('Redemption request not found');
    if (existing.status !== 'pending') throw new ValidationError('Only pending requests can be dispatched');

    const updated = await this.repo.fulfill(dto.redemptionId, dto.pinCode, dto.adminNotes);
    if (!updated) throw new NotFoundError('Failed to update redemption');

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

  public async rejectReward(dto: RejectRewardDto, adminId: string, adminEmail: string): Promise<RedemptionEntity> {
    const existing = await this.repo.findById(dto.redemptionId);
    if (!existing) throw new NotFoundError('Redemption request not found');
    if (existing.status !== 'pending') throw new ValidationError('Only pending requests can be rejected');

    const updated = await this.repo.reject(dto.redemptionId, dto.reason);
    if (!updated) throw new NotFoundError('Failed to reject redemption');

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
