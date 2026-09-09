import { db } from '../../database/db.service.js';
export class ComplianceRepository {
    async getDeletionRequests() {
        return Array.from(db.deletionRequests.values()).sort((a, b) => new Date(a.scheduledPurgeAt).getTime() - new Date(b.scheduledPurgeAt).getTime());
    }
    async findDeletionRequestById(id) {
        return db.deletionRequests.get(id) || null;
    }
    async executePurge(requestId) {
        const req = db.deletionRequests.get(requestId);
        if (!req)
            return null;
        req.status = 'completed';
        req.completedAt = new Date().toISOString();
        db.deletionRequests.set(requestId, req);
        // Irrevocably anonymize user account data for GDPR/Google Play compliance
        if (req.userId && db.users.has(req.userId)) {
            const user = db.users.get(req.userId);
            user.email = `anonymized_${user.id.substring(0, 8)}@deleted.local`;
            user.displayName = 'Deleted User';
            user.coinBalance = 0;
            user.deviceId = undefined;
            user.lastIp = undefined;
            db.users.set(user.id, user);
        }
        return req;
    }
    async getSupportTickets(status) {
        let tickets = Array.from(db.supportTickets.values());
        if (status && status !== 'all') {
            tickets = tickets.filter((t) => t.status === status);
        }
        return tickets.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    }
    async updateTicketStatus(ticketId, status) {
        const ticket = db.supportTickets.get(ticketId);
        if (!ticket)
            return null;
        ticket.status = status;
        if (status === 'resolved') {
            ticket.resolvedAt = new Date().toISOString();
        }
        db.supportTickets.set(ticketId, ticket);
        return ticket;
    }
}
