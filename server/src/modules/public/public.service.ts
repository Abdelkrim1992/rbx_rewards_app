import crypto from 'node:crypto';
import { PublicRepository } from './public.repository.js';
import { CreatePublicContactDto, CreatePublicDeletionDto } from './public.dto.js';
import { DeletionRequestEntity, SupportTicketEntity } from '../../database/db.service.js';

export interface PublicRewardCard {
  id: string;
  denomination: string;
  coinPrice: number;
  inStock: boolean;
  robuxEst: number;
}

export interface PublicGameCaps {
  tapTap: number;
  mathQuiz: number;
  flappyJump: number;
  flipCards: number;
  scratchCard: number;
  globalCap: number;
}

export interface PublicAppConfigResult {
  appName: string;
  packageName: string;
  version: string;
  rewards: PublicRewardCard[];
  dailyCaps: PublicGameCaps;
  sla: {
    deliveryHours: number;
    deletionDays: number;
    xpPerLevel: number;
  };
  stats: {
    totalCoinsAwarded: number;
    totalRedemptionsFulfilled: number;
    pendingRedemptions: number;
    averageDeliveryHours: number;
    systemStatus: string;
    uptimePercent: number;
  };
  lastUpdated: string;
}

export class PublicService {
  private readonly repository = new PublicRepository();

  public getAppConfig(): PublicAppConfigResult {
    const rawCards = this.repository.getSystemConfig('reward_cards')?.value;
    const rawCaps = this.repository.getSystemConfig('daily_caps')?.value;
    const stats = this.repository.getPlatformStats();

    const cardsArray = Array.isArray(rawCards?.['cards'])
      ? (rawCards?.['cards'] as Array<{ id: string; denomination: string; coinPrice: number; inStock: boolean }>)
      : [];

    const rewards: PublicRewardCard[] = cardsArray.map((c) => ({
      id: c.id,
      denomination: c.denomination,
      coinPrice: c.coinPrice,
      inStock: c.inStock,
      robuxEst: c.denomination === '$3' ? 240 : c.denomination === '$5' ? 400 : 800,
    }));

    const dailyCaps: PublicGameCaps = {
      tapTap: Number(rawCaps?.['tapTap'] ?? 150),
      mathQuiz: Number(rawCaps?.['mathQuiz'] ?? 120),
      flappyJump: Number(rawCaps?.['flappyJump'] ?? 150),
      flipCards: Number(rawCaps?.['flipCards'] ?? 60),
      scratchCard: Number(rawCaps?.['scratchCard'] ?? 100),
      globalCap: Number(rawCaps?.['globalCap'] ?? 1000),
    };

    return {
      appName: 'RBX Rewards',
      packageName: 'com.example.rbx_rewards',
      version: '1.4.0',
      rewards,
      dailyCaps,
      sla: {
        deliveryHours: 48,
        deletionDays: 7,
        xpPerLevel: 5000,
      },
      stats,
      lastUpdated: new Date().toISOString(),
    };
  }

  public submitContactTicket(dto: CreatePublicContactDto): { ticketId: string; message: string } {
    const ticketId = crypto.randomUUID();
    const mappedCategory = dto.topic.toLowerCase().includes('redemption')
      ? 'redemption'
      : dto.topic.toLowerCase().includes('coin')
      ? 'coins'
      : dto.topic.toLowerCase().includes('bug')
      ? 'game_issue'
      : 'account';

    const entity: SupportTicketEntity = {
      id: ticketId,
      userId: `guest_${crypto.randomBytes(4).toString('hex')}`,
      email: dto.email,
      subject: `[Web Ticket: ${dto.topic}] ${dto.name}`,
      category: mappedCategory,
      message: dto.message,
      status: 'open',
      createdAt: new Date().toISOString(),
    };

    this.repository.saveSupportTicket(entity);

    return {
      ticketId,
      message: 'Support inquiry logged successfully. Ticket assigned to compliance queue.',
    };
  }

  public submitDeletionRequest(dto: CreatePublicDeletionDto): {
    requestId: string;
    scheduledPurgeAt: string;
    message: string;
  } {
    const requestId = crypto.randomUUID();
    const now = new Date();
    const scheduledPurge = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000).toISOString();

    const entity: DeletionRequestEntity = {
      id: requestId,
      userId: dto.userId || `user_${crypto.randomBytes(6).toString('hex')}`,
      email: dto.email,
      reason: dto.reason,
      status: 'pending',
      requestedAt: now.toISOString(),
      scheduledPurgeAt: scheduledPurge,
    };

    this.repository.saveDeletionRequest(entity);

    return {
      requestId,
      scheduledPurgeAt: scheduledPurge,
      message: 'Deletion request scheduled per Google Play and Apple Store SLA.',
    };
  }
}
