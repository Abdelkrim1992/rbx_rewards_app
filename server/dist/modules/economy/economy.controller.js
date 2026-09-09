import { EconomyService } from './economy.service.js';
import { updateMiniGameCapsSchema, updateGlobalCapSchema } from './dto/update-caps.dto.js';
import { updateRewardCardSchema } from './dto/update-pricing.dto.js';
import { ValidationError, UnauthorizedError } from '../../core/app-error.js';
export class EconomyController {
    service;
    constructor(service = new EconomyService()) {
        this.service = service;
    }
    getConfigs = async (_req, res, next) => {
        try {
            const data = await this.service.getAllEconomyConfigs();
            res.status(200).json({ success: true, data });
        }
        catch (err) {
            next(err);
        }
    };
    updateCaps = async (req, res, next) => {
        try {
            if (!req.admin)
                throw new UnauthorizedError();
            const parseResult = updateMiniGameCapsSchema.safeParse(req.body);
            if (!parseResult.success) {
                throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
            }
            const result = await this.service.updateMiniGameCaps(parseResult.data, req.admin.adminId, req.admin.email);
            res.status(200).json({ success: true, data: result });
        }
        catch (err) {
            next(err);
        }
    };
    updateGlobalCap = async (req, res, next) => {
        try {
            if (!req.admin)
                throw new UnauthorizedError();
            const parseResult = updateGlobalCapSchema.safeParse(req.body);
            if (!parseResult.success) {
                throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
            }
            const result = await this.service.updateGlobalCap(parseResult.data, req.admin.adminId, req.admin.email);
            res.status(200).json({ success: true, data: result });
        }
        catch (err) {
            next(err);
        }
    };
    updateCard = async (req, res, next) => {
        try {
            if (!req.admin)
                throw new UnauthorizedError();
            const parseResult = updateRewardCardSchema.safeParse(req.body);
            if (!parseResult.success) {
                throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
            }
            const result = await this.service.updateRewardCard(parseResult.data, req.admin.adminId, req.admin.email);
            res.status(200).json({ success: true, data: result });
        }
        catch (err) {
            next(err);
        }
    };
}
