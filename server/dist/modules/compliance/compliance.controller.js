import { ComplianceService } from './compliance.service.js';
import { executePurgeSchema, resolveTicketSchema } from './dto/compliance.dto.js';
import { ValidationError, UnauthorizedError } from '../../core/app-error.js';
export class ComplianceController {
    service;
    constructor(service = new ComplianceService()) {
        this.service = service;
    }
    getDeletionQueue = async (_req, res, next) => {
        try {
            const data = await this.service.getDeletionQueue();
            res.status(200).json({ success: true, data });
        }
        catch (err) {
            next(err);
        }
    };
    executePurge = async (req, res, next) => {
        try {
            if (!req.admin)
                throw new UnauthorizedError();
            const parseResult = executePurgeSchema.safeParse(req.body);
            if (!parseResult.success) {
                throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
            }
            const result = await this.service.executePurge(parseResult.data, req.admin.adminId, req.admin.email);
            res.status(200).json({ success: true, data: result });
        }
        catch (err) {
            next(err);
        }
    };
    getTickets = async (req, res, next) => {
        try {
            const status = req.query['status'];
            const data = await this.service.getTickets(status);
            res.status(200).json({ success: true, data });
        }
        catch (err) {
            next(err);
        }
    };
    resolveTicket = async (req, res, next) => {
        try {
            if (!req.admin)
                throw new UnauthorizedError();
            const parseResult = resolveTicketSchema.safeParse(req.body);
            if (!parseResult.success) {
                throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
            }
            const result = await this.service.resolveTicket(parseResult.data, req.admin.adminId, req.admin.email);
            res.status(200).json({ success: true, data: result });
        }
        catch (err) {
            next(err);
        }
    };
}
