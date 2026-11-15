import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/app/shell/bottom_navigation_bar.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/app_update/application/app_update_provider.dart';
import 'package:muslimku/features/app_update/data/app_update_gateway.dart';
import 'package:muslimku/features/app_update/presentation/app_update_widgets.dart';
import 'package:muslimku/features/asmaul_husna/presentation/asmaul_husna_screen.dart';
import 'package:muslimku/features/doa/presentation/doa_screen.dart';
import 'package:muslimku/features/hadith/presentation/hadith_screen.dart';
import 'package:muslimku/features/home/presentation/home_tab.dart';
import 'package:muslimku/features/prayer/application/adzan_provider.dart';
import 'package:muslimku/features/prayer/application/home_widget_provider.dart';
import 'package:muslimku/features/quran/presentation/quran_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  static const _tabCount = 5;

  int _currentIndex = 0;

  /// Tabs are built on first visit and then kept alive, so switching back
  /// keeps their scroll position and does not download the data again.
  final Set<int> _visited = {0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Re-plan adzan reminders (14 days ahead) every time the app starts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(adzanProvider.notifier).reschedule();
      ref.read(appUpdateProvider.notifier).check();
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
      ref.read(appUpdateProvider.notifier).check(onResume: true);
    }
  }

  void _onUpdateState(AppUpdateState? previous, AppUpdateState next) {
    final notifier = ref.read(appUpdateProvider.notifier);
    if (next.failed) {
      notifier.failureShown();
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Pembaruan gagal diunduh. Coba lagi nanti.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
    final update = next.update;
    if (next.prompt && update != null) {
      notifier.promptShown();
      _offerUpdate(update);
    }
  }

  Future<void> _offerUpdate(AvailableUpdate update) async {
    // Never on top of another sheet or screen; the next check asks again.
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final choice = await showAppUpdateSheet(context, update);
    if (!mounted) return;
    final notifier = ref.read(appUpdateProvider.notifier);
    if (choice == UpdateChoice.update) {
      await notifier.accept();
    } else {
      await notifier.later();
    }
  }

  void _openTab(int index) {
    setState(() {
      _currentIndex = index;
      _visited.add(index);
    });
  }

  Widget _tab(int index) {
    if (!_visited.contains(index)) return const SizedBox.shrink();
    final Widget screen = switch (index) {
      HomeTabs.quran => const QuranScreen(),
      HomeTabs.hadith => const HadithScreen(),
      HomeTabs.asmaulHusna => const AsmaulHusnaScreen(),
      HomeTabs.doa => const DoaScreen(),
      _ => HomeTab(onOpenTab: _openTab),
    };
    // Hidden tabs keep their state but stop animating. Every tab draws its
    // own dusk header under the status bar.
    return TickerMode(enabled: index == _currentIndex, child: screen);
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the home-screen widget in step while the app is open.
    ref.watch(homeWidgetSyncProvider);
    ref.listen<AppUpdateState>(appUpdateProvider, _onUpdateState);
    final update = ref.watch(appUpdateProvider);
    final isHome = _currentIndex == 0;
    return PopScope(
      // Back on another tab goes to Beranda first; Back on Beranda leaves.
      canPop: isHome,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _openTab(0);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: AppColors.surface,
          body: Stack(
            children: [
              Positioned.fill(
                child: IndexedStack(
                  index: _currentIndex,
                  children: [for (var i = 0; i < _tabCount; i++) _tab(i)],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: update.showBanner
                      ? AppUpdateBanner(
                          key: ValueKey(update.phase),
                          phase: update.phase,
                          onInstall: () =>
                              ref.read(appUpdateProvider.notifier).install(),
                          onClose: () =>
                              ref.read(appUpdateProvider.notifier).hideBanner(),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
          bottomNavigationBar: CustomBottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _openTab,
          ),
        ),
      ),
    );
  }
}
