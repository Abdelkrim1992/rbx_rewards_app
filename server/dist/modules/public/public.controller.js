import { PublicService } from './public.service.js';
import { createPublicContactSchema, createPublicDeletionSchema } from './public.dto.js';
import { ValidationError } from '../../core/app-error.js';
export class PublicController {
    service;
    constructor(service = new PublicService()) {
        this.service = service;
    }
    getAppConfig = async (_req, res, next) => {
        try {
            const config = this.service.getAppConfig();
            res.status(200).json({ success: true, data: config });
        }
        catch (err) {
            next(err);
        }
    };
    submitContact = async (req, res, next) => {
        try {
            const parseResult = createPublicContactSchema.safeParse(req.body);
            if (!parseResult.success) {
                throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
            }
            const result = this.service.submitContactTicket(parseResult.data);
            res.status(201).json({ success: true, data: result });
        }
        catch (err) {
            next(err);
        }
    };
    submitDeletion = async (req, res, next) => {
        try {
            const parseResult = createPublicDeletionSchema.safeParse(req.body);
            if (!parseResult.success) {
                throw new ValidationError(parseResult.error.errors.map((e) => e.message).join(', '));
            }
            const result = this.service.submitDeletionRequest(parseResult.data);
            res.status(201).json({ success: true, data: result });
        }
        catch (err) {
            next(err);
        }
    };
}
