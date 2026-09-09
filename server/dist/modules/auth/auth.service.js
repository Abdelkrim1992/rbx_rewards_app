import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { AuthRepository } from './auth.repository.js';
import { env } from '../../core/env.config.js';
import { UnauthorizedError } from '../../core/app-error.js';
export class AuthService {
    authRepo;
    constructor(authRepo = new AuthRepository()) {
        this.authRepo = authRepo;
    }
    async login(dto) {
        const admin = await this.authRepo.findAdminByEmail(dto.email);
        if (!admin) {
            throw new UnauthorizedError('Invalid email or password');
        }
        const isPasswordValid = await bcrypt.compare(dto.password, admin.passwordHash);
        if (!isPasswordValid) {
            throw new UnauthorizedError('Invalid email or password');
        }
        const payload = {
            adminId: admin.id,
            email: admin.email,
            role: admin.role,
        };
        const accessToken = jwt.sign(payload, env.JWT_SECRET, {
            expiresIn: '8h',
        });
        return {
            accessToken,
            admin: {
                id: admin.id,
                email: admin.email,
                role: admin.role,
            },
        };
    }
}
