import { db } from '../../database/db.service.js';
export class EconomyRepository {
    async getConfig(key) {
        return db.systemConfigs.get(key) || null;
    }
    async setConfig(key, value, updatedBy) {
        const existing = db.systemConfigs.get(key);
        const updated = {
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
