import { env } from '../../core/env.config.js';

export interface AdminUserRecord {
  id: string;
  email: string;
  role: 'admin' | 'superadmin';
  passwordHash?: string;
}

export class AuthRepository {
  public async findAdminByEmail(email: string): Promise<AdminUserRecord | null> {
    if (email.toLowerCase() === env.ADMIN_EMAIL.toLowerCase()) {
      return {
        id: 'f9c09c99-9c0b-4ef8-bb6d-6bb9bd380001',
        email: env.ADMIN_EMAIL,
        role: 'superadmin',
        passwordHash: env.ADMIN_PASSWORD_HASH,
      };
    }
    return null;
  }
}
