import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

class RewardsSocialProofTicker extends StatefulWidget {
  const RewardsSocialProofTicker({super.key});

  @override
  State<RewardsSocialProofTicker> createState() =>
      _RewardsSocialProofTickerState();
}

class _RewardsSocialProofTickerState extends State<RewardsSocialProofTicker> {
  int _currentIndex = 0;
  Timer? _timer;

  static const List<_CashoutProofItem> _items = [
    _CashoutProofItem(
      icon: '🎉',
      text: 'Marcus redeemed \$10 Roblox Gift Card',
      timeAgo: '2m ago',
    ),
    _CashoutProofItem(
      icon: '💎',
      text: 'Sophia received 800 Robux PIN code',
      timeAgo: '5m ago',
    ),
    _CashoutProofItem(
      icon: '⚡',
      text: 'Liam redeemed \$5 Roblox Gift Card',
      timeAgo: '8m ago',
    ),
    _CashoutProofItem(
      icon: '🎁',
      text: 'Ethan claimed 1,000 Robux Code',
      timeAgo: '12m ago',
    ),
    _CashoutProofItem(
      icon: '🚀',
      text: 'Mia redeemed \$25 Roblox Digital Card',
      timeAgo: '16m ago',
    ),
    _CashoutProofItem(
      icon: '🔥',
      text: 'Noah claimed 400 Robux Instant Code',
      timeAgo: '21m ago',
    ),
    _CashoutProofItem(
      icon: '✨',
      text: 'Lucas received \$10 Roblox Digital Card',
      timeAgo: '27m ago',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 3800), (timer) {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % _items.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _items[_currentIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppLayout.screenPadding,
      ),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF9FE),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.cardBorder,
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            _buildLiveBadge(),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: _buildTransition,
                child: _buildItemRow(item),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F7F0),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFB7EAD4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF047857),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransition(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 0.4),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  Widget _buildItemRow(_CashoutProofItem item) {
    return Row(
      key: ValueKey<int>(_currentIndex),
      children: [
        Text(item.icon, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            item.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          item.timeAgo,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _CashoutProofItem {
  final String icon;
  final String text;
  final String timeAgo;

  const _CashoutProofItem({
    required this.icon,
    required this.text,
    required this.timeAgo,
  });
}
