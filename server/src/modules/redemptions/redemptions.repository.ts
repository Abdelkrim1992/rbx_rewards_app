import { db, RedemptionEntity } from '../../database/db.service.js';

export interface RedemptionFilterParams {
  status?: 'pending' | 'fulfilled' | 'rejected' | 'all';
  take: number;
  skip: number;
}

export class RedemptionsRepository {
  public async getRedemptions(params: RedemptionFilterParams): Promise<{ items: RedemptionEntity[]; total: number }> {
    let list = Array.from(db.redemptions.values());
    if (params.status && params.status !== 'all') {
      list = list.filter((r) => r.status === params.status);
    }
    list.sort((a, b) => new Date(a.requestedAt).getTime() - new Date(b.requestedAt).getTime());

    const total = list.length;
    const items = list.slice(params.skip, params.skip + params.take);
    return { items, total };
  }

  public async findById(id: string): Promise<RedemptionEntity | null> {
    return db.redemptions.get(id) || null;
  }

  public async fulfill(id: string, pinCode: string, adminNotes?: string): Promise<RedemptionEntity | null> {
    const item = db.redemptions.get(id);
    if (!item) return null;

    item.status = 'fulfilled';
    item.pinCode = pinCode;
    item.dispatchedAt = new Date().toISOString();
    item.adminNotes = adminNotes;
    db.redemptions.set(id, item);
    return item;
  }

  public async reject(id: string, reason: string): Promise<RedemptionEntity | null> {
    const item = db.redemptions.get(id);
    if (!item) return null;

    item.status = 'rejected';
    item.adminNotes = reason;
    db.redemptions.set(id, item);

    // Refund coins to user
    const user = db.users.get(item.userId);
    if (user) {
      user.coinBalance += item.cost;
      db.users.set(user.id, user);
    }

    return item;
  }
}
