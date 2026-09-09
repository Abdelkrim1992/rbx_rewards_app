import { EconomyRepository } from './economy.repository.js';
import { AuditService } from '../audit/audit.service.js';
import { UpdateMiniGameCapsDto, UpdateGlobalCapDto } from './dto/update-caps.dto.js';
import { UpdateRewardCardDto } from './dto/update-pricing.dto.js';
import { SystemConfigEntity } from '../../database/db.service.js';

export class EconomyService {
  constructor(
    private readonly repo: EconomyRepository = new EconomyRepository(),
    private readonly auditService: AuditService = new AuditService()
  ) {}

  public async getAllEconomyConfigs() {
    const miniGameCaps = await this.repo.getConfig('mini_game_caps');
    const globalCap = await this.repo.getConfig('global_feature_cap');
    const rewardCards = await this.repo.getConfig('reward_cards');

    return {
      miniGameCaps: miniGameCaps ? miniGameCaps.value : {},
      globalCap: globalCap ? globalCap.value : {},
      rewardCards: rewardCards ? rewardCards.value : {},
    };
  }

  public async updateMiniGameCaps(dto: UpdateMiniGameCapsDto, adminId: string, adminEmail: string): Promise<SystemConfigEntity> {
    const result = await this.repo.setConfig('mini_game_caps', dto as unknown as Record<string, unknown>, adminId);

    await this.auditService.logAction({
      adminId,
      adminEmail,
      action: 'UPDATE_MINI_GAME_CAPS',
      targetType: 'SYSTEM_CONFIG',
      targetId: 'mini_game_caps',
      details: dto as unknown as Record<string, unknown>,
    });

    return result;
  }

  public async updateGlobalCap(dto: UpdateGlobalCapDto, adminId: string, adminEmail: string): Promise<SystemConfigEntity> {
    const result = await this.repo.setConfig('global_feature_cap', dto as unknown as Record<string, unknown>, adminId);

    await this.auditService.logAction({
      adminId,
      adminEmail,
      action: 'UPDATE_GLOBAL_CAP',
      targetType: 'SYSTEM_CONFIG',
      targetId: 'global_feature_cap',
      details: dto as unknown as Record<string, unknown>,
    });

    return result;
  }

  public async updateRewardCard(dto: UpdateRewardCardDto, adminId: string, adminEmail: string): Promise<SystemConfigEntity> {
    const existingConfig = await this.repo.getConfig('reward_cards');
    const cardsData = (existingConfig?.value?.['cards'] as Array<Record<string, unknown>>) || [];

    const updatedCards = cardsData.map((c) => {
      if (c['id'] === dto.id) {
        return {
          ...c,
          coinPrice: dto.coinPrice,
          inStock: dto.inStock,
        };
      }
      return c;
    });

    const result = await this.repo.setConfig('reward_cards', { cards: updatedCards }, adminId);

    await this.auditService.logAction({
      adminId,
      adminEmail,
      action: 'UPDATE_REWARD_CARD',
      targetType: 'REWARD_CARD',
      targetId: dto.id,
      details: { coinPrice: dto.coinPrice, inStock: dto.inStock },
    });

    return result;
  }
}
