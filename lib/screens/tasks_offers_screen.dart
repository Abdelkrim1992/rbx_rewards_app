import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TasksOffersScreen extends StatelessWidget {
  const TasksOffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF131326)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tasks & Offers',
          style: TextStyle(
            color: Color(0xFF131326),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppLayout.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Complete tasks and offers to earn massive RBX!',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              
              // List of Offerwalls
              Column(
                children: [
                  _OfferCard(
                    iconUrl: AppAssets.clipboardIcon,
                    title: 'AdGem',
                    subtitle: 'High paying offers',
                    badge: 'Up to 10k',
                    badgeColor: AppColors.purple,
                    badgeBgColor: AppColors.primarySoft,
                    iconFallback: Icons.local_offer,
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  _OfferCard(
                    iconUrl: AppAssets.tapTapGame,
                    title: 'TapJoy',
                    subtitle: 'Play games & earn',
                    badge: 'Up to 5k',
                    badgeColor: AppColors.purple,
                    badgeBgColor: AppColors.primarySoft,
                    iconFallback: Icons.gamepad,
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  _OfferCard(
                    iconUrl: AppAssets.quizMasterGame,
                    title: 'IronSource',
                    subtitle: 'Quick tasks',
                    badge: 'Up to 2.5k',
                    badgeColor: AppColors.purple,
                    badgeBgColor: AppColors.primarySoft,
                    iconFallback: Icons.task_alt,
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  _OfferCard(
                    iconUrl: AppAssets.missionsIcon,
                    title: 'CPALead',
                    subtitle: 'Surveys & more',
                    badge: 'Up to 1k',
                    badgeColor: const Color(0xFF16A34A),
                    badgeBgColor: const Color(0xFFDCFCE7),
                    iconFallback: Icons.poll,
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  _OfferCard(
                    iconUrl: AppAssets.memoryMatchGame,
                    title: 'Watch Videos',
                    subtitle: 'Earn passively',
                    badge: '+50 RBX',
                    badgeColor: const Color(0xFFD4A017),
                    badgeBgColor: const Color(0xFFFFD700).withOpacity(0.2),
                    iconFallback: Icons.play_circle_filled,
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  _OfferCard(
                    iconUrl: AppAssets.chestIcon,
                    title: 'Daily Tasks',
                    subtitle: 'Complete everyday',
                    badge: 'Up to 500',
                    badgeColor: const Color(0xFFEA580C),
                    badgeBgColor: const Color(0xFFFFEDD5),
                    iconFallback: Icons.assignment_turned_in,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final String iconUrl;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final Color badgeBgColor;
  final IconData iconFallback;
  final VoidCallback onTap;

  const _OfferCard({
    required this.iconUrl,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.badgeBgColor,
    required this.iconFallback,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 15,
              offset: Offset(0, 8),
            ),
          ],
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Image.network(
              iconUrl,
              height: 54,
              width: 54,
              errorBuilder: (_, __, ___) => Icon(
                iconFallback,
                size: 46,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF131326),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF868A9F),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: badgeBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
