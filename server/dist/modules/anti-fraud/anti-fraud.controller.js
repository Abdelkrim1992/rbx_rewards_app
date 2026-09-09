import { AntiFraudService } from './anti-fraud.service.js';
import { banUserSchema, unbanUserSchema } from './dto/fraud-action.dto.js';
import { ValidationError, UnauthorizedError } from '../../core/app-error.js';
export class AntiFraudController {
    antiFraudService;
    constructor(antiFraudService = new AntiFraudService()) {
        this.antiFraudService = antiFraudService;
    }
    getAlerts = async (_req, res, next) => {
        try {
            const alerts = await this.antiFraudService.getAlerts();
            res.status(200).json({ success: true, data: alerts });
        }
        catch (err) {
            next(err);
        }
    };
    getFlaggedUsers = async (_req, res, next) => {
        try {
            const users = await this.antiFraudService.getFlaggedUsers();
            res.status(200).json({ success: true, data: users });
        }
        catch (err) {
            next(err);
        }
    };
    getClusters = async (_req, res, next) => {
        try {
            const clusters = await this.antiFraudService.getClusters();
            res.status(200).json({ success: true, data: clusters });
        }
        catch (err) {
            next(err);
        }
    };
    banUser = async (req, res, next) => {
        try {
            if (!req.admin)
                throw new UnauthorizedError();
            const parseResult = banUserSchema.safeParse(req.body);
            if (!parseResult.success) {
                throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
            }
            const updated = await this.antiFraudService.banUser(parseResult.data, req.admin.adminId, req.admin.email);
            res.status(200).json({ success: true, data: updated });
        }
        catch (err) {
            next(err);
        }
    };
    unbanUser = async (req, res, next) => {
        try {
            if (!req.admin)
                throw new UnauthorizedError();
            const parseResult = unbanUserSchema.safeParse(req.body);
            if (!parseResult.success) {
                throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
            }
            const updated = await this.antiFraudService.unbanUser(parseResult.data, req.admin.adminId, req.admin.email);
            res.status(200).json({ success: true, data: updated });
        }
        catch (err) {
            next(err);
        }
    };
}
