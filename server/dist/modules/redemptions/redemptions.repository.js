import { db } from '../../database/db.service.js';
export class RedemptionsRepository {
    async getRedemptions(params) {
        let list = Array.from(db.redemptions.values());
        if (params.status && params.status !== 'all') {
            list = list.filter((r) => r.status === params.status);
        }
        list.sort((a, b) => new Date(a.requestedAt).getTime() - new Date(b.requestedAt).getTime());
        const total = list.length;
        const items = list.slice(params.skip, params.skip + params.take);
        return { items, total };
    }
    async findById(id) {
        return db.redemptions.get(id) || null;
    }
    async fulfill(id, pinCode, adminNotes) {
        const item = db.redemptions.get(id);
        if (!item)
            return null;
        item.status = 'fulfilled';
        item.pinCode = pinCode;
        item.dispatchedAt = new Date().toISOString();
        item.adminNotes = adminNotes;
        db.redemptions.set(id, item);
        return item;
    }
    async reject(id, reason) {
        const item = db.redemptions.get(id);
        if (!item)
            return null;
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
