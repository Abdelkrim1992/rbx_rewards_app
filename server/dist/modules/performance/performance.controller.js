import { PerformanceService } from './performance.service.js';
import { purgeCacheSchema, updateTtlSchema } from './dto/purge-cache.dto.js';
import { ValidationError, UnauthorizedError } from '../../core/app-error.js';
export class PerformanceController {
    service;
    constructor(service = new PerformanceService()) {
        this.service = service;
    }
    getTelemetry = async (_req, res, next) => {
        try {
            const data = await this.service.getTelemetry();
            res.status(200).json({ success: true, data });
        }
        catch (err) {
            next(err);
        }
    };
    purgeCache = async (req, res, next) => {
        try {
            if (!req.admin)
                throw new UnauthorizedError();
            const parseResult = purgeCacheSchema.safeParse(req.body);
            if (!parseResult.success) {
                throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
            }
            const result = await this.service.purge(parseResult.data, req.admin.adminId, req.admin.email);
            res.status(200).json({ success: true, data: result });
        }
        catch (err) {
            next(err);
        }
    };
    updateTtl = async (req, res, next) => {
        try {
            if (!req.admin)
                throw new UnauthorizedError();
            const parseResult = updateTtlSchema.safeParse(req.body);
            if (!parseResult.success) {
                throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
            }
            const result = await this.service.updateTtl(parseResult.data, req.admin.adminId, req.admin.email);
            res.status(200).json({ success: true, data: result });
        }
        catch (err) {
            next(err);
        }
    };
}
