import { db, SystemConfigEntity } from '../../database/db.service.js';

export class EconomyRepository {
  public async getConfig(key: string): Promise<SystemConfigEntity | null> {
    return db.systemConfigs.get(key) || null;
  }

  public async setConfig(key: string, value: Record<string, unknown>, updatedBy?: string): Promise<SystemConfigEntity> {
    const existing = db.systemConfigs.get(key);
    const updated: SystemConfigEntity = {
      key,
      value,
      description: existing ? existing.description : 'System configuration parameter',
      updatedAt: new Date().toISOString(),
      updatedBy,
    };
    db.systemConfigs.set(key, updated);
    return updated;
  }
}
