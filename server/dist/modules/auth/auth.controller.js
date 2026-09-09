import { AuthService } from './auth.service.js';
import { loginSchema } from './dto/login.dto.js';
import { ValidationError } from '../../core/app-error.js';
export class AuthController {
    authService;
    constructor(authService = new AuthService()) {
        this.authService = authService;
    }
    login = async (req, res, next) => {
        try {
            const parseResult = loginSchema.safeParse(req.body);
            if (!parseResult.success) {
                const errorMsg = parseResult.error.errors.map((e) => e.message).join(', ');
                throw new ValidationError(errorMsg);
            }
            const result = await this.authService.login(parseResult.data);
            res.status(200).json({
                success: true,
                data: result,
            });
        }
        catch (err) {
            next(err);
        }
    };
    getSession = async (req, res) => {
        res.status(200).json({
            success: true,
            data: {
                admin: req.admin,
            },
        });
    };
}
