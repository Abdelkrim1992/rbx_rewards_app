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
import 'theme/app_theme.dart';
import 'utils/image_precache_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<bool> _initSupabase() async {
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    debugPrint(
        '⚠️ SUPABASE_URL or SUPABASE_ANON_KEY not provided. Running in offline mode.');
    return false;
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    debugPrint('✅ Supabase initialized: $supabaseUrl');
    return true;
  } catch (e) {
    debugPrint('❌ Supabase initialization failed: $e');
    return false;
  }
}

Future<ProviderContainer> _initStorageAndServices() async {
  final prefs = await SharedPreferences.getInstance();
  final hiveRepo = HiveRepository();
  try {
    await hiveRepo.init();
  } catch (e) {
    debugPrint('❌ Hive init failed: $e');
  }

  return ProviderContainer(
    overrides: [
      hiveRepositoryProvider.overrideWithValue(hiveRepo),
      onboardingCompletedProvider
          .overrideWith((ref) => OnboardingNotifier(prefs)),
    ],
  );
}

Future<void> _initDeviceAuth(ProviderContainer container) async {
  try {
    final auth = container.read(authServiceProvider);
    if (auth.currentUser == null) {
      try {
        await auth.signInWithDevice().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint(
                '⚠️ Device sign-in timed out, proceeding in offline mode');
            return null;
          },
        );
      } catch (e) {
        debugPrint('Failed to sign in with device on startup: $e');
      }
    }
  } catch (e) {
    debugPrint('❌ Auth initialization error: $e');
  }
}

Future<ProviderContainer> _bootstrapServices() async {
  try {
    final isSupabaseReady = await _initSupabase();
    final container = await _initStorageAndServices();

    if (isSupabaseReady) {
      unawaited(_initDeviceAuth(container));
    }
    return container;
  } catch (e) {
    debugPrint('❌ App bootstrap error: $e');
    return ProviderContainer();
  }
}

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
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (widget.container != null && isTest) {
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
        title: 'RBX Rewards',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF664DFF),
          ),
          fontFamily: 'Inter',
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
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

    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (_isInitComplete) {
      return const AppNavigator(key: ValueKey('app_nav'));
    }

    if (isTest && widget.container != null) {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isTest =
          !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
      if (!isTest) {
        _initDeferredServices();
      }
    });
  }

  void _initDeferredServices() {
    // Defer monetization SDKs until after boot screen and target screen are mounted
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
