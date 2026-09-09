import { PerformanceRepository } from './performance.repository.js';
import { AuditService } from '../audit/audit.service.js';
export class PerformanceService {
    repo;
    auditService;
    constructor(repo = new PerformanceRepository(), auditService = new AuditService()) {
        this.repo = repo;
        this.auditService = auditService;
    }
    async getTelemetry() {
        const start = Date.now();
        // Simulate edge latency calculation
        const edgeLatencyMs = Math.floor(Math.random() * 15) + 12;
        const redisLatencyMs = Math.floor(Math.random() * 8) + 5;
        const ttlSettings = await this.repo.getTtlSettings();
        return {
            status: 'healthy',
            serverUptimeSeconds: Math.floor(process.uptime()),
            edgeLatencyMs,
            redisLatencyMs,
            computedInMs: Date.now() - start,
            ttlSettings: ttlSettings ? ttlSettings.value : {},
        };
    }
    async purge(dto, adminId, adminEmail) {
        const invalidatedCount = await this.repo.purgeCache(dto.target);
        await this.auditService.logAction({
            adminId,
            adminEmail,
            action: 'PURGE_CACHE',
            targetType: 'REDIS_CACHE',
            targetId: dto.target,
            details: { target: dto.target, invalidatedCount },
        });
        return {
            success: true,
            target: dto.target,
            invalidatedCount,
            timestamp: new Date().toISOString(),
        };
    }
    async updateTtl(dto, adminId, adminEmail) {
        const result = await this.repo.updateTtlSettings(dto, adminId);
        await this.auditService.logAction({
            adminId,
            adminEmail,
            action: 'UPDATE_CACHE_TTL',
            targetType: 'REDIS_SETTINGS',
            targetId: 'cache_settings',
            details: dto,
        });
        return result;
    }
}
