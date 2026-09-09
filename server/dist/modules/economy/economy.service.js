import { EconomyRepository } from './economy.repository.js';
import { AuditService } from '../audit/audit.service.js';
export class EconomyService {
    repo;
    auditService;
    constructor(repo = new EconomyRepository(), auditService = new AuditService()) {
        this.repo = repo;
        this.auditService = auditService;
    }
    async getAllEconomyConfigs() {
        const miniGameCaps = await this.repo.getConfig('mini_game_caps');
        const globalCap = await this.repo.getConfig('global_feature_cap');
        const rewardCards = await this.repo.getConfig('reward_cards');
        return {
            miniGameCaps: miniGameCaps ? miniGameCaps.value : {},
            globalCap: globalCap ? globalCap.value : {},
            rewardCards: rewardCards ? rewardCards.value : {},
        };
    }
    async updateMiniGameCaps(dto, adminId, adminEmail) {
        const result = await this.repo.setConfig('mini_game_caps', dto, adminId);
        await this.auditService.logAction({
            adminId,
            adminEmail,
            action: 'UPDATE_MINI_GAME_CAPS',
            targetType: 'SYSTEM_CONFIG',
            targetId: 'mini_game_caps',
            details: dto,
        });
        return result;
    }
    async updateGlobalCap(dto, adminId, adminEmail) {
        const result = await this.repo.setConfig('global_feature_cap', dto, adminId);
        await this.auditService.logAction({
            adminId,
            adminEmail,
            action: 'UPDATE_GLOBAL_CAP',
            targetType: 'SYSTEM_CONFIG',
            targetId: 'global_feature_cap',
            details: dto,
        });
        return result;
    }
    async updateRewardCard(dto, adminId, adminEmail) {
        const existingConfig = await this.repo.getConfig('reward_cards');
        const cardsData = existingConfig?.value?.['cards'] || [];
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
