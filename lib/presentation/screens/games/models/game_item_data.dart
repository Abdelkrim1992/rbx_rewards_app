import 'package:flutter/material.dart';

enum GameCategory {
  all,
  arcade,
  brain,
  instant,
}

extension GameCategoryExtension on GameCategory {
  String get label {
    switch (this) {
      case GameCategory.all:
        return 'All';
      case GameCategory.arcade:
        return 'Arcade';
      case GameCategory.brain:
        return 'Brain & Quiz';
      case GameCategory.instant:
        return 'Instant Win';
    }
  }

  IconData get icon {
    switch (this) {
      case GameCategory.all:
        return Icons.auto_awesome_rounded;
      case GameCategory.arcade:
        return Icons.sports_esports_rounded;
      case GameCategory.brain:
        return Icons.psychology_rounded;
      case GameCategory.instant:
        return Icons.card_giftcard_rounded;
    }
  }
}

class GameItemData {
  final String id;
  final String title;
  final String subtitle;
  final String capKey;
  final String imageUrl;
  final GameCategory category;
  final Color themeColor;
  final Color softBgColor;
  final String badgeText;
  final Color badgeColor;
  final String difficulty;
  final String avgTime;
  final String description;
  final List<String> rules;
  final Future<int> Function()? getPersonalBest;
  final String personalBestUnit;
  final bool isSpotlight;
  final Widget Function(BuildContext context, Function(int) onNavTap) screenBuilder;

  const GameItemData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.capKey,
    required this.imageUrl,
    required this.category,
    required this.themeColor,
    required this.softBgColor,
    required this.badgeText,
    required this.badgeColor,
    required this.difficulty,
    required this.avgTime,
    required this.description,
    required this.rules,
    required this.screenBuilder,
    this.getPersonalBest,
    this.personalBestUnit = 'pts',
    this.isSpotlight = false,
  });
}
