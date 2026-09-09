import { db } from '../../database/db.service.js';
export class AntiFraudRepository {
    async getAlerts() {
        return Array.from(db.fraudAlerts.values()).sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    }
    async getFlaggedUsers() {
        return Array.from(db.users.values()).filter((u) => u.isEmulator || u.isBanned || db.fraudAlerts.get(u.id) !== undefined);
    }
    async findUserById(userId) {
        return db.users.get(userId) || null;
    }
    async updateUserBanState(userId, isBanned, reason) {
        const user = db.users.get(userId);
        if (!user)
            return null;
        user.isBanned = isBanned;
        user.banReason = isBanned ? reason : undefined;
        db.users.set(userId, user);
        return user;
    }
    async getMultiAccountClusters() {
        const deviceMap = new Map();
        for (const user of db.users.values()) {
            if (user.deviceId) {
                const list = deviceMap.get(user.deviceId) || [];
                list.push(user);
                deviceMap.set(user.deviceId, list);
            }
        }
        const clusters = [];
        for (const [deviceId, users] of deviceMap.entries()) {
            clusters.push({
                identifier: deviceId,
                type: 'device_id',
                accountCount: users.length,
                users: users.map((u) => ({
                    id: u.id,
                    email: u.email,
                    displayName: u.displayName,
                    isBanned: u.isBanned,
                })),
            });
        }
        return clusters;
    }
}
