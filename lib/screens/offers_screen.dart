import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/refreshable_scroll.dart';

class OffersScreen extends StatefulWidget {
  final Function(int) onNavTap;

  const OffersScreen({super.key, required this.onNavTap});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  String _selectedCategory = 'All';

  final _categories = ['All', 'Surveys', 'Apps', 'Games', 'Trials'];

  final List<_OfferData> _allOffers = const [
    // Featured (highest payout)
    _OfferData(
      icon: Icons.gamepad,
      title: 'Raid Shadow Legends',
      subtitle: 'Complete Tutorial',
      reward: 3000,
      category: 'Games',
      difficulty: 'Medium',
      estimatedTime: '15 min',
      isFeatured: true,
    ),
    _OfferData(
      icon: Icons.poll,
      title: 'Consumer Insights Survey',
      subtitle: 'Share your shopping habits',
      reward: 800,
      category: 'Surveys',
      difficulty: 'Easy',
      estimatedTime: '5 min',
    ),
    _OfferData(
      icon: Icons.shopping_bag,
      title: 'SHEIN Shopping',
      subtitle: 'Install app & register',
      reward: 1500,
      category: 'Apps',
      difficulty: 'Easy',
      estimatedTime: '3 min',
    ),
    _OfferData(
      icon: Icons.credit_card,
      title: 'Credit Karma',
      subtitle: 'Check your credit score',
      reward: 2000,
      category: 'Trials',
      difficulty: 'Easy',
      estimatedTime: '5 min',
    ),
    _OfferData(
      icon: Icons.casino,
      title: 'Coin Master',
      subtitle: 'Reach Village 3',
      reward: 2500,
      category: 'Games',
      difficulty: 'Hard',
      estimatedTime: '2 hours',
    ),
    _OfferData(
      icon: Icons.fitness_center,
      title: 'Sweatcoin',
      subtitle: 'Walk 1,000 steps',
      reward: 1800,
      category: 'Apps',
      difficulty: 'Medium',
      estimatedTime: '1 day',
    ),
    _OfferData(
      icon: Icons.quiz,
      title: 'Quick Poll',
      subtitle: 'Answer 3 simple questions',
      reward: 250,
      category: 'Surveys',
      difficulty: 'Easy',
      estimatedTime: '1 min',
    ),
    _OfferData(
      icon: Icons.local_pizza,
      title: 'DoorDash Delivery',
      subtitle: 'Place your first order',
      reward: 5000,
      category: 'Trials',
      difficulty: 'Medium',
      estimatedTime: '30 min',
    ),
    _OfferData(
      icon: Icons.music_note,
      title: 'Spotify Premium',
      subtitle: 'Start free trial',
      reward: 4000,
      category: 'Trials',
      difficulty: 'Easy',
      estimatedTime: '2 min',
    ),
    _OfferData(
      icon: Icons.videogame_asset,
      title: 'Candy Crush Saga',
      subtitle: 'Reach Level 15',
      reward: 2500,
      category: 'Games',
      difficulty: 'Hard',
      estimatedTime: '3 hours',
    ),
  ];

  List<_OfferData> get _filteredOffers {
    if (_selectedCategory == 'All') return _allOffers;
    return _allOffers.where((o) => o.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: RefreshableScrollView(
                padding: const EdgeInsets.only(bottom: 20, top:12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RbxAppHeader(onNavTap: widget.onNavTap),

                    // Section heading
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Offers & Tasks',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF131326),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_allOffers.length} offers available • Updated hourly',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF868A9F),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Featured Offer Hero Card
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: _FeaturedOfferCard(
                        data: _allOffers.firstWhere((o) => o.isFeatured),
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Category Filter Chips
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (ctx, i) {
                            final cat = _categories[i];
                            final isActive = cat == _selectedCategory;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedCategory = cat),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: isActive
                                      ? AppColors.primaryGradient
                                      : null,
                                  color:
                                      isActive ? null : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isActive
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Offer Count Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedCategory == 'All'
                                ? 'All Offers'
                                : '$_selectedCategory Offers',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF131326),
                            ),
                          ),
                          Text(
                            '${_filteredOffers.length} found',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF868A9F),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Offer List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      itemCount: _filteredOffers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final offer = _filteredOffers[i];
                        return _OfferListItem(
                          data: offer,
                          onTap: () {},
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // More offers banner
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Container(
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primarySoft,
                              AppColors.primarySoft.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.purple.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.local_offer,
                                  color: AppColors.purple, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'More offers added every hour',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryText,
                                ),
                              ),
                            ),
                            const Icon(Icons.layers,
                                color: AppColors.purple, size: 32),
                            const SizedBox(width: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: RbxBottomNav(currentIndex: 2, onTap: widget.onNavTap),
        ),
      ),
    );
  }
}

// ─── Data Model ───────────────────────────────────────────

class _OfferData {
  final IconData icon;
  final String title;
  final String subtitle;
  final int reward;
  final String category;
  final String difficulty;
  final String estimatedTime;
  final bool isFeatured;

  const _OfferData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.reward,
    required this.category,
    required this.difficulty,
    required this.estimatedTime,
    this.isFeatured = false,
  });
}

// ─── Featured Offer Hero Card ─────────────────────────────

class _FeaturedOfferCard extends StatelessWidget {
  final _OfferData data;
  final VoidCallback onTap;

  const _FeaturedOfferCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Featured badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'FEATURED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(data.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      data.estimatedTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on,
                          color: Color(0xFFFFCC44), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${data.reward} RBX',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF131326),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Offer List Item ──────────────────────────────────────

class _OfferListItem extends StatelessWidget {
  final _OfferData data;
  final VoidCallback onTap;

  const _OfferListItem({required this.data, required this.onTap});

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return const Color(0xFF27AE60);
      case 'Medium':
        return const Color(0xFFFF9800);
      case 'Hard':
        return const Color(0xFFE74C3C);
      default:
        return const Color(0xFF868A9F);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(data.icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF131326),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF868A9F),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Difficulty tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _difficultyColor(data.difficulty)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          data.difficulty,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _difficultyColor(data.difficulty),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Time tag
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer,
                              size: 12, color: Color(0xFF868A9F)),
                          const SizedBox(width: 3),
                          Text(
                            data.estimatedTime,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF868A9F),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Reward
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      AppAssets.goldRbxCoin,
                      width: 18,
                      height: 18,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.monetization_on,
                        size: 18,
                        color: Color(0xFFFFCC44),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${data.reward}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF131326),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
