import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav.dart';

class OffersScreen extends StatelessWidget {
  final Function(int) onNavTap;

  const OffersScreen({super.key, required this.onNavTap});

  final List<_OfferData> _offers = const [
    _OfferData(
      iconUrl: 'https://cdn3d.iconscout.com/3d/premium/thumb/candy-11172680-8996698.png',
      title: 'Candy Crush Saga',
      subtitle: 'Reach Level 15',
      reward: '+2,500',
    ),
    _OfferData(
      iconUrl: 'https://cdn3d.iconscout.com/3d/premium/thumb/clipboard-survey-9937084-8134762.png',
      title: 'Complete Survey',
      subtitle: 'Complete a 5-min Survey',
      reward: '+800',
    ),
    _OfferData(
      iconUrl: 'https://cdn3d.iconscout.com/3d/premium/thumb/beach-umbrella-6848699-5608670.png',
      title: 'Travel Town',
      subtitle: 'Install & Open',
      reward: '+1,200',
    ),
    _OfferData(
      iconUrl: 'https://cdn3d.iconscout.com/3d/premium/thumb/rocket-6848691-5608662.png',
      title: 'Raid Shadow Legends',
      subtitle: 'Complete Tutorial',
      reward: '+3,000',
    ),
    _OfferData(
      iconUrl: 'https://cdn3d.iconscout.com/3d/premium/thumb/shopping-bag-6848695-5608666.png',
      title: 'SHEIN Shopping',
      subtitle: 'Install & Register',
      reward: '+1,500',
    ),
    _OfferData(
      iconUrl: 'https://cdn3d.iconscout.com/3d/premium/thumb/credit-card-6848685-5608656.png',
      title: 'Credit Karma',
      subtitle: 'Check Your Score',
      reward: '+2,000',
    ),
    _OfferData(
      iconUrl: 'https://cdn3d.iconscout.com/3d/premium/thumb/game-controller-6848689-5608660.png',
      title: 'Coin Master',
      subtitle: 'Reach Village 3',
      reward: '+2,500',
    ),
    _OfferData(
      iconUrl: 'https://cdn3d.iconscout.com/3d/premium/thumb/mobile-phone-6848693-5608664.png',
      title: 'Sweatcoin',
      subtitle: 'Install & Walk 1,000 Steps',
      reward: '+1,800',
    ),
  ];

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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RbxAppHeader(onNavTap: onNavTap),
                    // Section heading
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Offers & Tasks',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF131326),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Complete offers and earn big RBX rewards',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF868A9F),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Offer cards grid (2-column, same as home screen)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final cardWidth = (constraints.maxWidth - 6) / 2;
                          return Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _offers.map((offer) {
                              return SizedBox(
                                width: cardWidth,
                                child: _OfferCard(
                                  iconUrl: offer.iconUrl,
                                  title: offer.title,
                                  subtitle: offer.subtitle,
                                  reward: offer.reward,
                                  onTap: () {},
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

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
                                'More offers added daily',
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
                    const SizedBox(height: AppLayout.sectionSpacing),
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
          child: RbxBottomNav(currentIndex: 2, onTap: onNavTap),
        ),
      ),
    );
  }
}

class _OfferData {
  final String iconUrl;
  final String title;
  final String subtitle;
  final String reward;

  const _OfferData({
    required this.iconUrl,
    required this.title,
    required this.subtitle,
    required this.reward,
  });
}

class _OfferCard extends StatelessWidget {
  final String iconUrl;
  final String title;
  final String subtitle;
  final String reward;
  final VoidCallback? onTap;

  const _OfferCard({
    required this.iconUrl,
    required this.title,
    required this.subtitle,
    required this.reward,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 15),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                iconUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_offer,
                    size: 24,
                    color: Color(0xFF6035EE),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF131326),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF868A9F),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Image.asset(
                        AppAssets.goldRbxCoin,
                        width: 16,
                        height: 16,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.monetization_on,
                          size: 16,
                          color: Color(0xFFFFCC44),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$reward RBX',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF131326),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
