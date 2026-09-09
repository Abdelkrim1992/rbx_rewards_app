import { db, SystemConfigEntity } from '../../database/db.service.js';

export class PerformanceRepository {
  public async purgeCache(target: 'leaderboard' | 'economy' | 'all'): Promise<number> {
    const pattern = target === 'all' ? '*' : target;
    return db.purgeRedisCache(pattern);
  }

  public async getTtlSettings(): Promise<SystemConfigEntity | null> {
    return db.systemConfigs.get('cache_settings') || null;
  }

  public async updateTtlSettings(value: Record<string, unknown>, updatedBy?: string): Promise<SystemConfigEntity> {
    const existing = db.systemConfigs.get('cache_settings');
    const updated: SystemConfigEntity = {
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
