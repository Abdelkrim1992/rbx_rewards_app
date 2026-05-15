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

class AppAssets {
  // Figma remote assets (7-day expiry)
  static const String heroIllustration =
      'https://www.figma.com/api/mcp/asset/a52090da-83a4-4bf9-8b86-0b1f96d18452';
  static const String gamepadIcon =
      'https://www.figma.com/api/mcp/asset/ef690607-7ba6-4db4-a851-b0dbca513fa0';
  static const String prizeWheelIcon =
      'https://www.figma.com/api/mcp/asset/9317869a-2a98-4f56-ae36-d822a541fd90';
  static const String treasureChestIcon =
      'https://www.figma.com/api/mcp/asset/6ffe8337-cad6-4012-9285-ac241b3ea726';

  // Home screen
  static const String rbxLogo =
      'https://www.figma.com/api/mcp/asset/022093a6-317c-43bd-88f0-1ef7ae9583c7';
  static const String userAvatar =
      'https://www.figma.com/api/mcp/asset/d61aa950-a3dd-42d9-a9a1-0cc4aed49d80';
  static const String wavingHand =
      'https://www.figma.com/api/mcp/asset/e32c7142-4714-4ff9-adef-c64da6cb1c12';
  static const String goldRbxCoin =
      'https://www.figma.com/api/mcp/asset/6e94d2d6-91dd-4ebc-bf8c-8767fc66b392';
  static const String arrowRight =
      'https://www.figma.com/api/mcp/asset/ea4bc6b7-3caa-4c49-9268-b6b6a4edf5d1';
  static const String purpleGiftBox =
      'https://www.figma.com/api/mcp/asset/9b9b8b26-0dd1-4994-a5fb-f6756ecbee9c';
  static const String chestIcon =
      'https://www.figma.com/api/mcp/asset/5ca17b86-c8ff-4cbe-a2ce-f24747e00d91';
  static const String spinWheelIcon =
      'https://www.figma.com/api/mcp/asset/b677e6f4-5285-4ecf-a9f9-d68a3b852e9b';
  static const String missionsIcon =
      'https://www.figma.com/api/mcp/asset/5fc9ce63-b939-4173-897c-114beeb03910';
  static const String clipboardIcon =
      'https://www.figma.com/api/mcp/asset/4f4ca268-c30e-4253-992e-5fba9647ace9';
  static const String tapTapGame =
      'https://www.figma.com/api/mcp/asset/f5dfa589-e054-470f-89a8-6508ae920620';
  static const String quizMasterGame =
      'https://www.figma.com/api/mcp/asset/cedd548f-dcba-48f4-9499-359f1cbcea15';
  static const String memoryMatchGame =
      'https://www.figma.com/api/mcp/asset/71b59327-cae4-4c8c-9183-792d2d287c55';
  static const String goldCoin =
      'https://www.figma.com/api/mcp/asset/a06d6636-99e2-480f-b5c6-fef2646cf3ee';
  static const String chevronRight =
      'https://www.figma.com/api/mcp/asset/916d584b-02ff-4889-9930-e32e15172357';

  // Nav icons
  static const String navHome =
      'https://www.figma.com/api/mcp/asset/d38cd333-4ae6-4ee4-b55b-0a03213a164b';
  static const String navGames =
      'https://www.figma.com/api/mcp/asset/58ef2751-2206-44b4-afa9-253df4b996ce';
  static const String navRewards =
      'https://www.figma.com/api/mcp/asset/4e879785-63b3-48dc-9f5f-8c6550dc4fb8';
  static const String navProfile =
      'https://www.figma.com/api/mcp/asset/459482cf-86a7-4e07-bb3b-09ecf20414df';

  // Profile screen
  static const String profileAvatar =
      'https://www.figma.com/api/mcp/asset/4f8e6556-cadb-4412-9bf7-205c4dabf108';
  static const String fireStreak =
      'https://www.figma.com/api/mcp/asset/e37e3720-4a49-4671-a975-d17d9310d228';
  static const String rbxCoinIcon =
      'https://www.figma.com/api/mcp/asset/6921107d-4c98-4ee6-9a99-da1d24d54104';
  static const String gamepadStat =
      'https://www.figma.com/api/mcp/asset/cca1114d-4f18-4f05-8da3-e8beacb8f47e';
  static const String adsWatched =
      'https://www.figma.com/api/mcp/asset/d5592f50-706e-44b8-9184-978388a85b05';
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
  static const String flappyJumpGame =
      'https://www.figma.com/api/mcp/asset/71b59327-cae4-4c8c-9183-792d2d287c55';
}
