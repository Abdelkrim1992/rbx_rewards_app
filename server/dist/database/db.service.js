class InMemoryDatabase {
    users = new Map();
    redemptions = new Map();
    fraudAlerts = new Map();
    systemConfigs = new Map();
    deletionRequests = new Map();
    supportTickets = new Map();
    auditLogs = [];
    redisCache = new Map();
    constructor() {
        this.seedDefaults();
    }
    reset() {
        this.users.clear();
        this.redemptions.clear();
        this.fraudAlerts.clear();
        this.systemConfigs.clear();
        this.deletionRequests.clear();
        this.supportTickets.clear();
        this.auditLogs = [];
        this.redisCache.clear();
        this.seedDefaults();
    }
    seedDefaults() {
        const now = new Date();
        const twoHoursAgo = new Date(now.getTime() - 2 * 3600 * 1000).toISOString();
        const fourtyHoursAgo = new Date(now.getTime() - 40 * 3600 * 1000).toISOString();
        const sevenDaysAhead = new Date(now.getTime() + 7 * 86400 * 1000).toISOString();
        // 1. Seed Users
        const u1 = {
            id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
            email: 'player1@example.com',
            displayName: 'RobloxGamer99',
            coinBalance: 24500,
            isBanned: false,
            isEmulator: false,
            deviceId: 'android_samsung_s23_001',
            lastIp: '192.168.1.42',
            createdAt: twoHoursAgo,
        };
        const u2 = {
            id: 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
            email: 'emulator_bot@example.com',
            displayName: 'SpeedFarmerX',
            coinBalance: 75000,
            isBanned: false,
            banReason: undefined,
            isEmulator: true,
            deviceId: 'vbox86p_bluestacks_device',
            lastIp: '45.33.32.156',
            createdAt: fourtyHoursAgo,
        };
        const u3 = {
            id: 'c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
            email: 'legit_user@example.com',
            displayName: 'BlockMaster2026',
            coinBalance: 42000,
            isBanned: false,
            isEmulator: false,
            deviceId: 'iphone_15_pro_max_003',
            lastIp: '72.14.201.2',
            createdAt: twoHoursAgo,
        };
        this.users.set(u1.id, u1);
        this.users.set(u2.id, u2);
        this.users.set(u3.id, u3);
        // 2. Seed Redemptions
        const r1 = {
            id: 'd3eebc99-9c0b-4ef8-bb6d-6bb9bd380a44',
            userId: u1.id,
            userEmail: u1.email,
            rewardTitle: '$3 Roblox Digital Gift Card',
            denomination: '$3',
            cost: 20000,
            status: 'pending',
            requestedAt: twoHoursAgo,
        };
        const r2 = {
            id: 'e4eebc99-9c0b-4ef8-bb6d-6bb9bd380a55',
            userId: u2.id,
            userEmail: u2.email,
            rewardTitle: '$10 Roblox Digital Gift Card',
            denomination: '$10',
            cost: 70000,
            status: 'pending',
            requestedAt: fourtyHoursAgo, // Approaching 48h SLA
        };
        this.redemptions.set(r1.id, r1);
        this.redemptions.set(r2.id, r2);
        // 3. Seed Fraud Alerts
        const f1 = {
            id: 'f5eebc99-9c0b-4ef8-bb6d-6bb9bd380a66',
            userId: u2.id,
            userEmail: u2.email,
            alertType: 'emulator_detected',
            severity: 'critical',
            details: {
                detectedHardware: 'BlueStacks 5 Virtual Hardware (vbox86p)',
                buildFingerprint: 'google/vbox86p/vbox86p:9/PQ3A.190801.002:userdebug/test-keys',
            },
            isResolved: false,
            createdAt: fourtyHoursAgo,
        };
        const f2 = {
            id: 'f6eebc99-9c0b-4ef8-bb6d-6bb9bd380a77',
            userId: u2.id,
            userEmail: u2.email,
            alertType: 'score_velocity_spike',
            severity: 'high',
            details: {
                game: 'flappy_jump',
                scoreVelocity: '8.4 gates/sec',
                normalThreshold: '2.0 gates/sec',
                durationSeconds: 12,
                scoreAchieved: 101,
            },
            isResolved: false,
            createdAt: fourtyHoursAgo,
        };
        this.fraudAlerts.set(f1.id, f1);
        this.fraudAlerts.set(f2.id, f2);
        // 4. Seed System Configs
        this.systemConfigs.set('mini_game_caps', {
            key: 'mini_game_caps',
            value: {
                tap_tap: 150,
                math_quiz: 120,
                flappy_jump: 150,
                flip_cards: 60,
                scratch_card: 100,
            },
            description: 'Daily coin limits per mini-game',
            updatedAt: now.toISOString(),
        });
        this.systemConfigs.set('global_feature_cap', {
            key: 'global_feature_cap',
            value: { cap: 1000 },
            description: 'Daily cap across streak, chest and wheel',
            updatedAt: now.toISOString(),
        });
        this.systemConfigs.set('reward_cards', {
            key: 'reward_cards',
            value: {
                cards: [
                    { id: 'card_3', denomination: '$3', coinPrice: 20000, inStock: true },
                    { id: 'card_5', denomination: '$5', coinPrice: 40000, inStock: true },
                    { id: 'card_10', denomination: '$10', coinPrice: 70000, inStock: true },
                ],
            },
            description: 'Roblox gift card inventory & coin costs',
            updatedAt: now.toISOString(),
        });
        this.systemConfigs.set('cache_settings', {
            key: 'cache_settings',
            value: {
                leaderboardTtlSeconds: 60,
                economyTtlSeconds: 300,
            },
            description: 'Redis Edge Cache TTL settings',
            updatedAt: now.toISOString(),
        });
        // 5. Seed Deletion Requests
        const d1 = {
            id: '01eebc99-9c0b-4ef8-bb6d-6bb9bd380a88',
            userId: '77eebc99-9c0b-4ef8-bb6d-6bb9bd380a99',
            email: 'delete_me@example.com',
            reason: 'No longer playing the game',
            status: 'pending',
            requestedAt: now.toISOString(),
            scheduledPurgeAt: sevenDaysAhead,
        };
        this.deletionRequests.set(d1.id, d1);
        // 6. Seed Support Ticket
        const t1 = {
            id: '12eebc99-9c0b-4ef8-bb6d-6bb9bd380a00',
            userId: u1.id,
            email: u1.email,
            subject: 'Inquiry regarding $3 gift card delivery time',
            category: 'redemption',
            message: 'Hello, I requested my gift card 2 hours ago. Will it arrive within the 48 hour SLA?',
            status: 'open',
            createdAt: twoHoursAgo,
        };
        this.supportTickets.set(t1.id, t1);
        // 7. Seed Initial System Audit Log
        this.auditLogs.push({
            id: '99eebc99-9c0b-4ef8-bb6d-6bb9bd380a99',
            adminId: 'f9c09c99-9c0b-4ef8-bb6d-6bb9bd380001',
            adminEmail: 'admin@rbxrewards.com',
            action: 'SYSTEM_BOOT',
            targetType: 'SYSTEM',
            targetId: 'NODE_CLUSTER_01',
            details: { environment: 'production', status: 'ready' },
            createdAt: now.toISOString(),
        });
    }
    purgeRedisCache(pattern) {
        let count = 0;
        for (const key of this.redisCache.keys()) {
            if (pattern === '*' || key.includes(pattern)) {
                this.redisCache.delete(key);
                count++;
            }
        }
        return count;
    }
}
export const db = new InMemoryDatabase();
