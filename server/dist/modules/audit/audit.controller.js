import { AuditService } from './audit.service.js';
export class AuditController {
    auditService;
    constructor(auditService = new AuditService()) {
        this.auditService = auditService;
    }
    getLogs = async (req, res, next) => {
        try {
            const take = parseInt(req.query['take'] || '20', 10);
            const skip = parseInt(req.query['skip'] || '0', 10);
            const result = await this.auditService.getAuditTrail({ take, skip });
            res.status(200).json({
                success: true,
                data: result,
            });
        }
        catch (err) {
            next(err);
        }
    };
}
