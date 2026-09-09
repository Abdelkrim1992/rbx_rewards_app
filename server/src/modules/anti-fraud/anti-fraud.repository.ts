import { db, UserEntity, FraudAlertEntity } from '../../database/db.service.js';

export interface MultiAccountCluster {
  identifier: string;
  type: 'device_id' | 'ip_address';
  accountCount: number;
  users: Array<{ id: string; email: string; displayName: string; isBanned: boolean }>;
}

export class AntiFraudRepository {
  public async getAlerts(): Promise<FraudAlertEntity[]> {
    return Array.from(db.fraudAlerts.values()).sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );
  }

  public async getFlaggedUsers(): Promise<UserEntity[]> {
    return Array.from(db.users.values()).filter(
      (u) => u.isEmulator || u.isBanned || db.fraudAlerts.get(u.id) !== undefined
    );
  }

  public async findUserById(userId: string): Promise<UserEntity | null> {
    return db.users.get(userId) || null;
  }

  public async updateUserBanState(userId: string, isBanned: boolean, reason?: string): Promise<UserEntity | null> {
    const user = db.users.get(userId);
    if (!user) return null;

    user.isBanned = isBanned;
    user.banReason = isBanned ? reason : undefined;
    db.users.set(userId, user);
    return user;
  }

  public async getMultiAccountClusters(): Promise<MultiAccountCluster[]> {
    const deviceMap = new Map<string, UserEntity[]>();
    for (const user of db.users.values()) {
      if (user.deviceId) {
        const list = deviceMap.get(user.deviceId) || [];
        list.push(user);
        deviceMap.set(user.deviceId, list);
      }
    }

    const clusters: MultiAccountCluster[] = [];
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
