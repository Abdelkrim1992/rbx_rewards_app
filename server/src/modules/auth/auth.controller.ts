import { Request, Response, NextFunction } from 'express';
import { AuthService } from './auth.service.js';
import { loginSchema } from './dto/login.dto.js';
import { ValidationError } from '../../core/app-error.js';

export class AuthController {
  constructor(private readonly authService: AuthService = new AuthService()) {}

  public login = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
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
    } catch (err: unknown) {
      next(err);
    }
  };

  public getSession = async (req: Request, res: Response): Promise<void> => {
    res.status(200).json({
      success: true,
      data: {
        admin: req.admin,
      },
    });
  };
}
