import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/game_service.dart';
import '../theme/app_theme.dart';

class LeaderboardScreen extends StatefulWidget {
  final VoidCallback onBack;

  const LeaderboardScreen({super.key, required this.onBack});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with WidgetsBindingObserver {
  List<_LeaderboardEntry> _entries = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLeaderboard();
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadLeaderboard();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadLeaderboard();
    }
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await GameService().getLeaderboard(limit: 10);
      String? currentUserId;
      try {
        currentUserId = Supabase.instance.client.auth.currentUser?.id;
      } catch (_) {
        currentUserId = null;
      }
      final entries = data
          .map((e) => _LeaderboardEntry(
                rank: (e['rank'] as num?)?.toInt() ?? 0,
                name: e['display_name'] as String? ?? 'Anonymous',
                avatar: ((e['display_name'] as String? ?? 'A'))
                    .substring(0, 1)
                    .toUpperCase(),
                coins: (e['coins'] as num?)?.toInt() ?? 0,
                isUser: e['user_id'] == currentUserId,
              ))
          .toList();
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  int _bonusForRank(int rank) {
    switch (rank) {
      case 1:
        return 500;
      case 2:
        return 300;
      case 3:
        return 100;
      default:
        if (rank <= 10) return 50;
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEntry = _entries.isNotEmpty
        ? _entries.firstWhere(
            (e) => e.isUser,
            orElse: () => const _LeaderboardEntry(
                rank: 0, name: 'You', avatar: 'Y', coins: 0, isUser: true),
          )
        : const _LeaderboardEntry(
            rank: 0, name: 'You', avatar: 'Y', coins: 0, isUser: true);
    final userBonus = _bonusForRank(userEntry.rank);

    final podiumEntries = List<_LeaderboardEntry>.from(_entries);
    while (podiumEntries.length < 3) {
      final rank = podiumEntries.length + 1;
      podiumEntries.add(_LeaderboardEntry(
        rank: rank,
        name: 'Empty Slot',
        avatar: '-',
        coins: 0,
        isUser: false,
      ));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SizedBox(
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: widget.onBack,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: AppColors.purple,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      'All-Time Leaderboard',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF131326),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Top earners across all time',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF868A9F),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),

            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load leaderboard',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF131326),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF868A9F),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadLeaderboard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_entries.isEmpty)
              Expanded(
                child: _EmptyLeaderboardState(
                  onPlayGames: widget.onBack,
                ),
              )
            else ...[
              // Podium (Top 3)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 2nd place
                    _PodiumItem(
                      entry: podiumEntries[1],
                      height: 100,
                      color: const Color(0xFF9CA3AF),
                      bonus: _bonusForRank(2),
                    ),
                    const SizedBox(width: 12),
                    // 1st place
                    _PodiumItem(
                      entry: podiumEntries[0],
                      height: 130,
                      color: const Color(0xFFFFCC44),
                      bonus: _bonusForRank(1),
                      isFirst: true,
                    ),
                    const SizedBox(width: 12),
                    // 3rd place
                    _PodiumItem(
                      entry: podiumEntries[2],
                      height: 80,
                      color: const Color(0xFFD97706),
                      bonus: _bonusForRank(3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // User rank highlight (if not in top 3)
              if (userEntry.rank > 3)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 2,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '#${userEntry.rank}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your Rank',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${userEntry.coins} RBX earned',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '+$userBonus RBX',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // Rankings list (#4-#10)
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadLeaderboard,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount:
                        _entries.length > 3 ? min(7, _entries.length - 3) : 0,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final entry = _entries[i + 3];
                      final bonus = _bonusForRank(entry.rank);
                      return _LeaderboardListItem(
                        entry: entry,
                        bonus: bonus,
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LeaderboardEntry {
  final int rank;
  final String name;
  final String avatar;
  final int coins;
  final bool isUser;

  const _LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.avatar,
    required this.coins,
    this.isUser = false,
  });
}

class _PodiumItem extends StatelessWidget {
  final _LeaderboardEntry entry;
  final double height;
  final Color color;
  final int bonus;
  final bool isFirst;

  const _PodiumItem({
    required this.entry,
    required this.height,
    required this.color,
    required this.bonus,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = entry.name == 'Empty Slot' || entry.coins == 0;

    return Expanded(
      child: Column(
        children: [
          // Avatar
          Container(
            width: isFirst ? 64 : 52,
            height: isFirst ? 64 : 52,
            decoration: BoxDecoration(
              gradient: isEmpty
                  ? const LinearGradient(
                      colors: [Color(0xFFE5E7EB), Color(0xFFD1D5DB)])
                  : AppColors.primaryGradient,
              shape: BoxShape.circle,
              border: isFirst && !isEmpty
                  ? Border.all(color: const Color(0xFFFFCC44), width: 3)
                  : null,
            ),
            child: Center(
              child: Text(
                isEmpty ? '-' : entry.avatar,
                style: TextStyle(
                  fontSize: isFirst ? 24 : 18,
                  fontWeight: FontWeight.w900,
                  color: isEmpty ? const Color(0xFF9CA3AF) : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isEmpty ? 'No Player' : entry.name,
            style: TextStyle(
              fontSize: isFirst ? 14 : 12,
              fontWeight: FontWeight.w800,
              color:
                  isEmpty ? const Color(0xFF9CA3AF) : const Color(0xFF131326),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            isEmpty ? '0 RBX' : '${entry.coins} RBX',
            style: TextStyle(
              fontSize: isFirst ? 13 : 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF868A9F),
            ),
          ),
          const SizedBox(height: 4),
          Opacity(
            opacity: isEmpty ? 0.3 : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '+$bonus',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Podium bar
          Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isEmpty
                    ? [
                        const Color(0xFFE5E7EB).withOpacity(0.5),
                        const Color(0xFFF3F4F6).withOpacity(0.2),
                      ]
                    : [
                        color.withOpacity(0.5),
                        color.withOpacity(0.2),
                      ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Center(
              child: Text(
                '#${entry.rank}',
                style: TextStyle(
                  fontSize: isFirst ? 18 : 14,
                  fontWeight: FontWeight.w900,
                  color: isEmpty ? const Color(0xFF9CA3AF) : color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardListItem extends StatelessWidget {
  final _LeaderboardEntry entry;
  final int bonus;

  const _LeaderboardListItem({required this.entry, required this.bonus});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: entry.isUser ? const Color(0xFFF3F4FE) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: entry.isUser
              ? AppColors.purple.withOpacity(0.3)
              : const Color(0xFFF3F4F6),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 2,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: entry.isUser
                  ? AppColors.purple.withOpacity(0.15)
                  : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#${entry.rank}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color:
                      entry.isUser ? AppColors.purple : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                entry.avatar,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name & Coins
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: entry.isUser
                        ? AppColors.purple
                        : const Color(0xFF131326),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.coins} RBX',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF868A9F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Bonus
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+$bonus',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFF8C00),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLeaderboardState extends StatelessWidget {
  final VoidCallback onPlayGames;

  const _EmptyLeaderboardState({required this.onPlayGames});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing Trophy Container
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.purple.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFFFCC44),
                  size: 52,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Rankings Yet',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF131326),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to earn RBX this week and claim the top spot on the leaderboard!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF868A9F),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: onPlayGames,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.purple.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Play Games Now',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
