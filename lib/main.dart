/*
 * ============================================================================
 * RBX REWARDS APPLICATION
 *
 * Copyright (c) 2024-2026 Abdelkrim Salaghe & Youssef. All rights reserved.
 *
 * Founders & Project Leadership:
 * - Abdelkrim Salaghe: Founder, Lead Software Architect & Primary Developer
 * - Youssef: Co-Founder & App Publishing Partner
 *
 * This software, source code, design architecture, and related digital assets
 * are proprietary intellectual property authored and owned by the founders
 * named above.
 * ============================================================================
 */

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/screens/loading_screen.dart';
import 'presentation/providers/ad_provider.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/spin_screen.dart';
import 'presentation/screens/games_screen.dart';
import 'presentation/screens/rewards_screen.dart';
import 'presentation/screens/profile_screen.dart';
import 'widgets/quit_confirmation_dialog.dart';
import 'data/hive_repository.dart';
import 'presentation/providers/providers.dart';
import 'presentation/providers/user_provider.dart';
import 'presentation/providers/coin_provider.dart';
import 'business/lucky_bonus_service.dart';
import 'business/tapjoy_service.dart';
import 'business/pubscale_service.dart';
import 'business/sound_service.dart';
import 'business/notification_service.dart';
import 'theme/app_theme.dart';
import 'utils/image_precache_helper.dart';
import 'presentation/providers/reward_provider.dart';
import 'presentation/screens/chest_screen.dart' deferred as chest_screen;
import 'widgets/deferred_game_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_secrets.dart';

Future<bool> _initSupabase() async {
  // Keys come from AppSecrets — auto-generated from env.json before every build.
  // No --dart-define flags needed. See tool/generate_secrets.dart.
  final supabaseUrl = AppSecrets.SUPABASE_URL;
  final supabaseAnonKey = AppSecrets.SUPABASE_ANON_KEY;

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    debugPrint(
        '⚠️ SUPABASE_URL or SUPABASE_ANON_KEY not set. Running in offline mode.');
    return false;
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    ).timeout(const Duration(milliseconds: 1500));
    debugPrint('✅ Supabase initialized: $supabaseUrl');
    return true;
  } catch (e) {
    debugPrint('⚠️ Supabase init timed out or failed ($e). Launching offline with background retry.');
    unawaited(_retrySupabaseInitInBackground(supabaseUrl, supabaseAnonKey));
    return false;
  }
}

Future<void> _retrySupabaseInitInBackground(
    String supabaseUrl, String supabaseAnonKey) async {
  try {
    await Future.delayed(const Duration(seconds: 3));
    try {
      Supabase.instance.client;
      return;
    } catch (_) {}
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    debugPrint('✅ Supabase background retry connected successfully');
  } catch (e) {
    debugPrint('ℹ️ Supabase background retry notice: $e');
  }
}

Future<ProviderContainer> _bootstrapServices() async {
  try {
    final hiveRepo = HiveRepository();

    // 1. Parallelize core offline-first storage and Supabase initialization
    final results = await Future.wait([
      _initSupabase(),
      SharedPreferences.getInstance(),
      hiveRepo.init().then((_) => true).catchError((e) {
        debugPrint('❌ Hive init failed: $e');
        return false;
      }),
    ]);

    final isSupabaseReady = results[0] as bool;
    final prefs = results[1] as SharedPreferences;

    final container = ProviderContainer(
      overrides: [
        hiveRepositoryProvider.overrideWithValue(hiveRepo),
        onboardingCompletedProvider
            .overrideWith((ref) => OnboardingNotifier(prefs)),
      ],
    );

    // 2. Fast in-memory session check (ZERO blocking network calls on startup)
    if (isSupabaseReady) {
      _initStartupAuthFast(container);
    }

    return container;
  } catch (e) {
    debugPrint('❌ App bootstrap error: $e');
    return ProviderContainer();
  }
}

void _initStartupAuthFast(ProviderContainer container) {
  try {
    final auth = container.read(authServiceProvider);
    if (auth.currentUser != null) {
      debugPrint('🔑 Active session found: ${auth.currentUser?.email ?? auth.currentUser?.id}');
      // Fast bypass onboarding carousel for authenticated returning user
      container.read(onboardingCompletedProvider.notifier).setCompleted(true);
    } else {
      debugPrint('ℹ️ No active session on startup. Onboarding sign-in gate will be shown.');
    }
  } catch (e) {
    debugPrint('❌ Fast auth initialization note: $e');
  }
}

/// true when running integration/E2E tests.
/// Set via env.json: "INTEGRATION_TEST": "true"
/// Generated automatically into AppSecrets by tool/generate_secrets.dart
bool get kIsIntegrationTest => AppSecrets.isIntegrationTest;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Optimize in-memory image cache for fast navigation without re-decoding
  PaintingBinding.instance.imageCache.maximumSize = 250;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 150 << 20; // 150 MB

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  SystemChrome.setSystemUIOverlayStyle(RbxRewardsApp.globalSystemOverlayStyle);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Launch Flutter immediately so the cold boot screen displays without delay
  runApp(const RbxRewardsApp());
}

class RbxRewardsApp extends StatefulWidget {
  final ProviderContainer? container;
  const RbxRewardsApp({super.key, this.container});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const SystemUiOverlayStyle globalSystemOverlayStyle =
      SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarDividerColor: Color(0xFFF1F1F4),
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  @override
  State<RbxRewardsApp> createState() => _RbxRewardsAppState();
}

class _RbxRewardsAppState extends State<RbxRewardsApp> {
  late ProviderContainer _container;
  bool _isInitComplete = false;

  @override
  void initState() {
    super.initState();
    _container = widget.container ?? ProviderContainer();
    // Skip cold-boot LoadingScreen when a pre-built container is injected (E2E tests)
    if (widget.container != null && kIsIntegrationTest) {
      _isInitComplete = true;
    }
  }

  bool _hasOuterScope(BuildContext context) {
    try {
      ProviderScope.containerOf(context, listen: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget app = AnnotatedRegion<SystemUiOverlayStyle>(
      value: RbxRewardsApp.globalSystemOverlayStyle,
      child: MaterialApp(
        navigatorKey: RbxRewardsApp.navigatorKey,
        title: 'RBX Rewards',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF664DFF),
          ),
          fontFamily: 'Inter',
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.cardBorder, width: 1.0),
            ),
            color: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: AppColors.primary.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          appBarTheme: const AppBarTheme(
            systemOverlayStyle: RbxRewardsApp.globalSystemOverlayStyle,
          ),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: RevolutPageTransitionsBuilder(),
              TargetPlatform.iOS: RevolutPageTransitionsBuilder(),
              TargetPlatform.windows: RevolutPageTransitionsBuilder(),
              TargetPlatform.macOS: RevolutPageTransitionsBuilder(),
              TargetPlatform.linux: RevolutPageTransitionsBuilder(),
            },
          ),
        ),
        builder: (context, child) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: RbxRewardsApp.globalSystemOverlayStyle,
            child: Container(
              color: const Color(
                  0xFFF0F0F0), // Subtle background color outside the app area
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: ClipRect(child: child),
                ),
              ),
            ),
          );
        },
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curvedAnimation,
              child: child,
            );
          },
          child: _buildHome(context),
        ),
      ),
    );

    if (_hasOuterScope(context)) {
      return app;
    }

    return UncontrolledProviderScope(
      key: const ValueKey('app_scope'),
      container: _container,
      child: app,
    );
  }

  Widget _buildHome(BuildContext context) {
    if (_hasOuterScope(context)) {
      return const AppNavigator(key: ValueKey('app_nav'));
    }

    // E2E test path: skip LoadingScreen when container is pre-built
    if (kIsIntegrationTest && widget.container != null) {
      return const AppNavigator(key: ValueKey('app_nav'));
    }

    // Production path: show AppNavigator once bootstrap completes
    if (_isInitComplete) {
      return const AppNavigator(key: ValueKey('app_nav'));
    }

    return LoadingScreen(
      key: const ValueKey('cold_boot_screen'),
      onBootstrap: () => widget.container != null
          ? Future.value(widget.container!)
          : _bootstrapServices(),
      onReady: (container) {
        if (mounted) {
          setState(() {
            _container = container;
            _isInitComplete = true;
          });
        }
      },
    );
  }
}

class AppNavigator extends ConsumerStatefulWidget {
  const AppNavigator({super.key});

  @override
  ConsumerState<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends ConsumerState<AppNavigator>
    with WidgetsBindingObserver {
  int _currentTab = 0;
  bool _showSpin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.instance.selectNotificationPayload
        .addListener(_onNotificationPayload);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!kIsIntegrationTest) {
        _initDeferredServices();
      }
    });
  }

  void _onNotificationPayload() {
    final payload =
        NotificationService.instance.selectNotificationPayload.value;
    if (payload == null || !mounted) return;
    NotificationService.instance.selectNotificationPayload.value = null;

    if (payload == NotificationService.payloadChest) {
      _openChestFromNotification();
    } else if (payload == NotificationService.payloadQuests) {
      _onNavTap(0);
      ref.read(dailyHubTabProvider.notifier).state = 1;
    } else if (payload == NotificationService.payloadStreak) {
      _onNavTap(0);
      ref.read(dailyHubTabProvider.notifier).state = 0;
    } else if (payload == NotificationService.payloadWelcome) {
      _onNavTap(0);
    }
  }

  void _openChestFromNotification() {
    _onNavTap(0);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeferredGameLoader(
          title: 'Mystery Chest',
          themeColor: AppColors.primary,
          iconAsset: AppAssets.chestIcon,
          loadLibrary: chest_screen.loadLibrary,
          builder: () => chest_screen.ChestScreen(),
        ),
      ),
    );
  }

  void _initDeferredServices() {
    // 1. Pre-warm secondary dashboard assets & SVGs after first frame is safely rendered
    ImagePrecacheHelper.precacheBackground(context);

    // 2. Initialize sound & local notifications asynchronously in background
    Future.microtask(() async {
      try {
        await SoundService.instance.init();
        await NotificationService.instance.init();
        await NotificationService.instance.scheduleDailyQuestsReminder();

        final cooldown = ref.read(dailyRewardCooldownProvider);
        final isClaimedToday = cooldown.inSeconds > 0;
        await NotificationService.instance.scheduleStreakReminder(
          isClaimedToday: isClaimedToday,
        );
      } catch (e) {
        debugPrint('Deferred background services note: $e');
      }
    });

    // 3. Defer monetization SDKs until after boot screen and target screen are mounted
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      try {
        ref.read(adProvider.notifier).initialize();
        LuckyBonusService().load();
        LuckyBonusService().startTracking();

        final auth = ref.read(authServiceProvider);
        final userId = auth.currentUser?.id ?? 'anonymous';
        PubscaleService().initialize(userId);
        PubscaleService().onReward = (amount, currency) {
          ref.read(coinProvider.notifier).refresh();
        };

        TapjoyService().initialize();
        TapjoyService().onClosed = () {
          ref.read(coinProvider.notifier).refresh();
        };
      } catch (e) {
        debugPrint('Deferred monetization services error: $e');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.instance.selectNotificationPayload
        .removeListener(_onNotificationPayload);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-sync coin balance from backend when app comes back to foreground.
      // Picks up any coins earned from offerwalls/webhooks while app was backgrounded.
      ref.read(coinProvider.notifier).refresh();
    }
  }

  Future<void> _onGetStarted() async {
    // Only allow entering the app if user has authenticated (or in testing environment)
    final auth = ref.read(authServiceProvider);
    if (auth.currentUser == null) {
      if (!kIsIntegrationTest) {
        debugPrint('⚠️ Cannot complete onboarding without an authenticated account.');
        return;
      }
    }
    await ref.read(onboardingCompletedProvider.notifier).setCompleted(true);
  }

  void _onNavTap(int index) {
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    setState(() {
      _currentTab = index;
      _showSpin = false;
    });
  }

  void _goToSpin() {
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    setState(() => _showSpin = true);
  }

  void _backFromSpin() {
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    setState(() => _showSpin = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(onboardingCompletedProvider, (previous, next) {
      if (!next && (previous == true || previous == null)) {
        setState(() {
          _currentTab = 0;
          _showSpin = false;
        });
      }
    });

    final onboardingCompleted = ref.watch(onboardingCompletedProvider);

    Widget destination;
    if (!onboardingCompleted) {
      destination = OnboardingScreen(
        key: const ValueKey('onboarding'),
        onGetStarted: _onGetStarted,
      );
    } else if (_showSpin) {
      destination = SpinScreen(
        key: const ValueKey('spin'),
        onBack: _backFromSpin,
      );
    } else {
      final screen = switch (_currentTab) {
        0 => HomeScreen(onNavTap: _onNavTap, onSpinTap: _goToSpin),
        1 => GamesScreen(onNavTap: _onNavTap),
        2 => RewardsScreen(onNavTap: _onNavTap),
        3 => ProfileScreen(onNavTap: _onNavTap),
        _ => HomeScreen(onNavTap: _onNavTap, onSpinTap: _goToSpin),
      };
      destination = PopScope(
        key: ValueKey('tab_$_currentTab'),
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (_showSpin) {
            _backFromSpin();
            return;
          }
          if (_currentTab != 0) {
            _onNavTap(0);
            return;
          }
          final shouldQuit = await showQuitConfirmationDialog(
            context,
            title: 'Quit App?',
            message: 'Are you sure you want to exit RBX Rewards?',
          );
          if (shouldQuit && context.mounted) {
            if (!kIsWeb && Platform.isAndroid) {
              SystemNavigator.pop();
            } else if (!kIsWeb) {
              Navigator.of(context).pop();
            }
          }
        },
        child: screen,
      );
    }

    final isSplashTransition =
        destination.key == const ValueKey('onboarding');
    final transitionDuration = isSplashTransition
        ? const Duration(milliseconds: 600)
        : const Duration(milliseconds: 320);

    // Premium fintech cross-fade + subtle slide transition like Wise & Revolut
    return AnimatedSwitcher(
      duration: transitionDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.035),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
      child: destination,
    );
  }
}
