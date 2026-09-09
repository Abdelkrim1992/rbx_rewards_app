import { db } from '../../database/db.service.js';
export class PerformanceRepository {
    async purgeCache(target) {
        const pattern = target === 'all' ? '*' : target;
        return db.purgeRedisCache(pattern);
    }
    async getTtlSettings() {
        return db.systemConfigs.get('cache_settings') || null;
    }
    async updateTtlSettings(value, updatedBy) {
        const existing = db.systemConfigs.get('cache_settings');
        const updated = {
            key: 'cache_settings',
            value,
            description: existing?.description || 'Redis Cache TTL settings',
            updatedAt: new Date().toISOString(),
            updatedBy,
        };
        db.systemConfigs.set('cache_settings', updated);
        return updated;
    }
}
