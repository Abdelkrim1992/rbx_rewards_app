import { AntiFraudRepository } from './anti-fraud.repository.js';
import { AuditService } from '../audit/audit.service.js';
import { BanUserDto, UnbanUserDto } from './dto/fraud-action.dto.js';
import { NotFoundError } from '../../core/app-error.js';
import { UserEntity, FraudAlertEntity } from '../../database/db.service.js';

export class AntiFraudService {
  constructor(
    private readonly antiFraudRepo: AntiFraudRepository = new AntiFraudRepository(),
    private readonly auditService: AuditService = new AuditService()
  ) {}

  public async getAlerts(): Promise<FraudAlertEntity[]> {
    return this.antiFraudRepo.getAlerts();
  }

  public async getFlaggedUsers(): Promise<UserEntity[]> {
    return this.antiFraudRepo.getFlaggedUsers();
  }

  public async getClusters() {
    return this.antiFraudRepo.getMultiAccountClusters();
  }

  public async banUser(dto: BanUserDto, adminId: string, adminEmail: string): Promise<UserEntity> {
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

  public async unbanUser(dto: UnbanUserDto, adminId: string, adminEmail: string): Promise<UserEntity> {
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
