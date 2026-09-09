import { PerformanceRepository } from './performance.repository.js';
import { AuditService } from '../audit/audit.service.js';
import { PurgeCacheDto, UpdateTtlDto } from './dto/purge-cache.dto.js';
import { SystemConfigEntity } from '../../database/db.service.js';

export class PerformanceService {
  constructor(
    private readonly repo: PerformanceRepository = new PerformanceRepository(),
    private readonly auditService: AuditService = new AuditService()
  ) {}

  public async getTelemetry() {
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

  public async purge(dto: PurgeCacheDto, adminId: string, adminEmail: string) {
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

  public async updateTtl(dto: UpdateTtlDto, adminId: string, adminEmail: string): Promise<SystemConfigEntity> {
    const result = await this.repo.updateTtlSettings(dto as unknown as Record<string, unknown>, adminId);

    await this.auditService.logAction({
      adminId,
      adminEmail,
      action: 'UPDATE_CACHE_TTL',
      targetType: 'REDIS_SETTINGS',
      targetId: 'cache_settings',
      details: dto as unknown as Record<string, unknown>,
    });

    return result;
  }
}
