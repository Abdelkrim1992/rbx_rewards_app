import dotenv from 'dotenv';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { z } from 'zod';
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
// Prioritize server-local .env, then process.cwd() .env, then monorepo root .env
dotenv.config({ path: path.resolve(__dirname, '../../.env') });
dotenv.config({ path: path.resolve(process.cwd(), '.env') });
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });
const envSchema = z.object({
    NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
    PORT: z.string().transform((val) => parseInt(val, 10)).default('4000'),
    JWT_SECRET: z.string().min(16).default('rbx_rewards_admin_super_secret_jwt_key_2026_safe'),
    ADMIN_EMAIL: z.string().email().default('admin@rbxrewards.com'),
    ADMIN_PASSWORD_HASH: z.string().optional(),
    SUPABASE_URL: z.string().url().optional(),
    SUPABASE_ANON_KEY: z.string().optional(),
    UPSTASH_REDIS_REST_URL: z.string().url().optional(),
    UPSTASH_REDIS_REST_TOKEN: z.string().optional(),
});
function loadEnv() {
    const result = envSchema.safeParse(process.env);
    if (!result.success) {
        const errorDetails = result.error.errors.map((e) => `${e.path.join('.')}: ${e.message}`).join(', ');
        throw new Error(`Environment validation failure: ${errorDetails}`);
    }
    return result.data;
}
export const env = loadEnv();
