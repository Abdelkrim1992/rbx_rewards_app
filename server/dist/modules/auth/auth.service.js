import { createClient } from '@supabase/supabase-js';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { AuthRepository } from './auth.repository.js';
import { env } from '../../core/env.config.js';
import { UnauthorizedError } from '../../core/app-error.js';
export class AuthService {
    supabase = null;
    authRepo;
    constructor(authRepo = new AuthRepository()) {
        this.authRepo = authRepo;
        if (env.SUPABASE_URL && env.SUPABASE_ANON_KEY) {
            this.supabase = createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY);
        }
    }
    async login(dto) {
        // 1. If Supabase is configured, authenticate securely against Supabase Auth
        // Password is verified in the cloud; no password or hash is ever stored in the project.
        if (this.supabase) {
            try {
                const { data, error } = await this.supabase.auth.signInWithPassword({
                    email: dto.email,
                    password: dto.password,
                });
                if (!error && data.user) {
                    const userEmail = data.user.email ?? dto.email;
                    const isAdmin = userEmail.toLowerCase() === env.ADMIN_EMAIL.toLowerCase() ||
                        data.user.app_metadata?.role === 'admin' ||
                        data.user.user_metadata?.role === 'admin';
                    if (!isAdmin) {
                        throw new UnauthorizedError('Access denied: Admin privileges required');
                    }
                    const payload = {
                        adminId: data.user.id,
                        email: userEmail,
                        role: 'superadmin',
                    };
                    const accessToken = jwt.sign(payload, env.JWT_SECRET, {
                        expiresIn: '8h',
                    });
                    return {
                        accessToken,
                        admin: {
                            id: data.user.id,
                            email: userEmail,
                            role: 'superadmin',
                        },
                    };
                }
            }
            catch (err) {
                if (err instanceof UnauthorizedError) {
                    throw err;
                }
                // Fall through to fallback check if Supabase is offline or in local test mode
            }
        }
        // 2. Fallback check (for local offline testing if an env hash is explicitly provided)
        const admin = await this.authRepo.findAdminByEmail(dto.email);
        if (!admin || !admin.passwordHash) {
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
