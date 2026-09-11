import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF6035EE);
  static const Color primaryLight = Color(0xFF8C62F8);
  static const Color primarySoft = Color(0xFFF1EDFF);
  static const Color primaryText = Color(0xFF131326);
  static const Color secondaryText = Color(0xFF868A9F);
  static const Color mutedText = Color(0xFF9A9DB2);
  static const Color purple = Color(0xFF664DFF);
  static const Color white = Colors.white;
  static const Color background = Colors.white;
  static const Color cardBorder = Color(0xFFF3F3F5);
  static const Color divider = Color(0xFFF1F2F8);
  static const Color navBorder = Color(0xFFF2F4F7);
  static const Color darkText = Color(0xFF0F172A);
  static const Color slateText = Color(0xFF64748B);
  static const Color slateBody = Color(0xFF334155);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF8C62F8), Color(0xFF6035EE)],
  );

  static const LinearGradient dailyCardGradient = LinearGradient(
    begin: Alignment(0.44, -0.9),
    end: Alignment(0.44, 0.9),
    colors: [Color(0xFFEFECFF), Color(0xFFDFD6FF)],
  );

  static const LinearGradient balanceCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.fromARGB(255, 136, 104, 231), // Vibrant purple matching wallet coin image
      Color.fromARGB(255, 155, 121, 255), // Dominant purple matching wallet coin image
      Color(0xFFAA8EFF), // Deep purple-indigo matching dark wallet coin tones
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient xpBarGradient = LinearGradient(
    colors: [Color(0xFF6B4BF4), Color(0xFF886EF6)],
  );

  // Wheel segment colors
  static const Color segment1 = Color(0xFF9B5CFF);
  static const Color segment2 = Color(0xFF7B3FE4);
  static const Color segment3 = Color(0xFFB370FF);
  static const Color segment4 = Color(0xFF6A2FD8);
  static const Color segment5 = Color(0xFFFFCC44);
  static const Color segment6 = Color(0xFF8847F5);
}

/// Centralized storage configuration for Supabase Storage CDN (Cloudflare edge)
class AppStorage {
  static const String supabaseProjectUrl =
      'https://onzyllkmzpykfecexruc.supabase.co';

  static const String bucketName = 'app-assets';

  /// Cloudflare-backed Supabase CDN Base URL for app assets
  /// Cloudflare-backed Supabase CDN Base URL for ultra-fast WebP images (30-80 KB, <25ms download)
  static const String webpCdnBaseUrl =
      '$supabaseProjectUrl/storage/v1/object/public/$bucketName/webp';

  /// Cloudflare-backed Supabase CDN Base URL for raw images
  static const String cdnBaseUrl =
      '$supabaseProjectUrl/storage/v1/object/public/$bucketName/images';

  /// Cloudflare / Supabase on-the-fly image transformation URL
  static String renderUrl(String assetPathOrName, {int? width, int quality = 85}) {
    final fileName = assetPathOrName.contains('/')
        ? assetPathOrName.split('/').last
        : assetPathOrName;
    final base =
        '$supabaseProjectUrl/storage/v1/render/image/public/$bucketName/images/$fileName';
    if (width != null) {
      return '$base?width=$width&quality=$quality&format=origin';
    }
    return base;
  }

  /// Maps an asset path (e.g. 'assets/images/tap_tap_mini_game.png')
  /// to its ultra-fast Supabase WebP CDN URL.
  static String toCdnUrl(String assetPathOrName, {bool preferWebp = true}) {
    if (assetPathOrName.startsWith('http://') ||
        assetPathOrName.startsWith('https://')) {
      return assetPathOrName;
    }
    var fileName = assetPathOrName.contains('/')
        ? assetPathOrName.split('/').last
        : assetPathOrName;

    if (preferWebp) {
      final baseName = fileName.split('.').first;
      return '$webpCdnBaseUrl/$baseName.webp';
    }

    // Match exact uppercase extension in Supabase Storage
    if (fileName.toLowerCase() == 'flip_cards_mini_game.png') {
      fileName = 'flip_cards_mini_game.PNG';
    } else if (fileName.toLowerCase() == 'first_rbx_card.png') {
      fileName = 'first_rbx_card.PNG';
    } else if (fileName.toLowerCase() == 'second_rbx_card.png') {
      fileName = 'second_rbx_card.PNG';
    } else if (fileName.toLowerCase() == 'thirty_rbx_reward.png') {
      fileName = 'thirty_rbx_reward.PNG';
    }

    return '$cdnBaseUrl/$fileName';
  }
}

class AppAssets {
  static const String onboardingHero =
      'assets/images/onboarding_screen_main_image.webp';
  static const String onboardingGiftBox =
      'assets/images/onboarding_gift_box.webp';
  static const String onboardingGame =
      'assets/images/game_image_onboarding.webp';
  static const String onboardingCoin =
      'assets/images/coin_image_onboarding.webp';
  static const String onboardingReward =
      'assets/images/reward_image_onboarding.webp';
  static const String bootImage =
      'assets/images/boot_image.webp';

  // Feature cards
  static const String firstFeatureCard =
      'assets/images/first_feature_card.webp';
  static const String secondFeatureCard =
      'assets/images/second_feature_card.webp';
  static const String thirtyFeatureCard =
      'assets/images/thirty_feature_card.webp';

  // App Icon & Logos
  static const String appIcon = 'assets/images/logo_image.webp';
  static const String rbxLogo = 'assets/images/logo_image.webp';
  static const String goldRbxCoin = 'assets/images/robux_coins.webp';
  static const String balanceWidgetImage =
      'assets/images/balance_widget_image.webp';
  static const String dailyRewardImage = 'assets/images/daily_reward_image.webp';
  static const String dailyRewardGift = 'assets/images/daily_reward_gift.webp';
  static const String chestIcon = 'assets/images/open_chest_quick_actions.webp';
  static const String spinWheelIcon = 'assets/images/spin_quick_action.webp';
  static const String tapTapGame = 'assets/images/tap_tap_mini_game.webp';
  static const String quizMasterGame = 'assets/images/math_quiz_mini_game.webp';
  static const String quizMasterQuickActions =
      'assets/images/quiz_master_quick_actions.webp';
  static const String memoryMatchGame = 'assets/images/flip_cards_mini_game.webp';
  static const String goldCoin = 'assets/images/robux_coins.webp';
  static const String megaChest = 'assets/images/mega_chest.webp';
  
  // Redeem rewards cards
  static const String roblox3UsdCard = 'assets/images/roblox_3usd_card.webp';
  static const String roblox5UsdCard = 'assets/images/roblox_5usd_card.webp';
  static const String roblox10UsdCard = 'assets/images/roblox_10usd_card.webp';

  // Supabase CDN URLs for remote loading with local storage caching
  static String get onboardingHeroCdn => AppStorage.toCdnUrl(onboardingHero);
  static String get onboardingGiftBoxCdn => AppStorage.toCdnUrl(onboardingGiftBox);
  static String get onboardingGameCdn => AppStorage.toCdnUrl(onboardingGame);
  static String get onboardingCoinCdn => AppStorage.toCdnUrl(onboardingCoin);
  static String get onboardingRewardCdn => AppStorage.toCdnUrl(onboardingReward);
  static String get balanceWidgetImageCdn => AppStorage.toCdnUrl(balanceWidgetImage);
  static String get dailyRewardImageCdn => AppStorage.toCdnUrl(dailyRewardImage);
  static String get dailyRewardGiftCdn => AppStorage.toCdnUrl(dailyRewardGift);
  static String get chestIconCdn => AppStorage.toCdnUrl(chestIcon);
  static String get spinWheelIconCdn => AppStorage.toCdnUrl(spinWheelIcon);
  static String get tapTapGameCdn => AppStorage.toCdnUrl(tapTapGame);
  static String get quizMasterGameCdn => AppStorage.toCdnUrl(quizMasterGame);
  static String get quizMasterQuickActionsCdn => AppStorage.toCdnUrl(quizMasterQuickActions);
  static String get memoryMatchGameCdn => AppStorage.toCdnUrl(memoryMatchGame);
  static String get flappyJumpGameCdn => AppStorage.toCdnUrl(flappyJumpGame);
  static String get megaChestCdn => AppStorage.toCdnUrl(megaChest);
  static String get roblox3UsdCardCdn => AppStorage.toCdnUrl(roblox3UsdCard);
  static String get roblox5UsdCardCdn => AppStorage.toCdnUrl(roblox5UsdCard);
  static String get roblox10UsdCardCdn => AppStorage.toCdnUrl(roblox10UsdCard);
  static String get gamepadStatCdn => AppStorage.toCdnUrl(gamepadStat);

  // Nav icons
  static const String navHome =
      'assets/icons/home-nav.svg';
  static const String navGames =
      'assets/icons/games-nav.svg';
  static const String navOffers =
      'https://cdn3d.iconscout.com/3d/premium/thumb/gift-box-6848695-5608666.png';
  static const String navRewards =
      'assets/icons/reward-nav.svg';
  static const String navProfile =
      'assets/icons/profile-nav.svg';

  // Profile screen
  static const String profileAvatar = 'assets/images/profile_image.webp';

  static const String rbxCoinIcon = 'assets/images/robux_coins.webp';
  static const String gamepadStat = 'assets/images/games-played.webp';
  static const String levelBadge =
      'https://www.figma.com/api/mcp/asset/159497f0-c81d-4613-8ec9-67c29e197137';
  static const String helpIcon =
      'https://www.figma.com/api/mcp/asset/c8feb69a-8356-47c3-bb7b-723504e434c1';
  static const String privacyIcon =
      'https://www.figma.com/api/mcp/asset/5790addd-49f3-42b9-83f7-0ff007604301';
  static const String termsIcon =
      'https://www.figma.com/api/mcp/asset/c3de76ce-35bd-4aa3-bd37-4813ad278385';
  static const String contactIcon =
      'https://www.figma.com/api/mcp/asset/e6dafc79-8710-4cac-a1ec-555574455b53';

  // Games screen
  static const String flappyJumpGame = 'assets/images/flappy_mini_game.webp';

  /// Assets to precache in memory on app startup for instant rendering
  static const List<String> allPrecacheAssets = [
    appIcon,
    rbxLogo,
    onboardingHero,
    onboardingGiftBox,
    onboardingGame,
    onboardingCoin,
    onboardingReward,
    firstFeatureCard,
    secondFeatureCard,
    thirtyFeatureCard,
    goldRbxCoin,
    balanceWidgetImage,
    dailyRewardImage,
    dailyRewardGift,
    chestIcon,
    spinWheelIcon,
    tapTapGame,
    quizMasterGame,
    quizMasterQuickActions,
    memoryMatchGame,
    megaChest,
    roblox3UsdCard,
    roblox5UsdCard,
    roblox10UsdCard,
    profileAvatar,
    gamepadStat,
    flappyJumpGame,
  ];

  /// Navigation SVGs to preload
  static const List<String> allPrecacheSvgs = [
    navHome,
    navGames,
    navRewards,
    navProfile,
  ];

  /// Dynamic remote CDN images to pre-warm into local persistent storage
  static List<String> get allPrecacheNetworkImages => const [];
}

class AppLayout {
  static const double screenPadding = 15.0;
  static const double sectionSpacing = 20.0;
  static const double elementSpacing = 12.0;
}

class RevolutPageTransitionsBuilder extends PageTransitionsBuilder {
  const RevolutPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final secondaryCurved = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.04, 0.0),
      ).animate(secondaryCurved),
      child: FadeTransition(
        opacity: Tween<double>(
          begin: 1.0,
          end: 0.88,
        ).animate(secondaryCurved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.08, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        ),
      ),
    );
  }
}
