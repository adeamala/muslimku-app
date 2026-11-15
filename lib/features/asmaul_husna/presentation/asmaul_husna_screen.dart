import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/asmaul_husna/application/asmaul_husna_provider.dart';
import 'package:muslimku/features/asmaul_husna/presentation/husna_actions.dart';
import 'package:muslimku/features/asmaul_husna/presentation/husna_name_card.dart';
import 'package:muslimku/features/asmaul_husna/presentation/husna_today_card.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// Asmaul Husna tab (design-v2 a1): name of the day, the 99 names in a grid,
/// a Hafalan mode that hides the meanings, and the quiz.
class AsmaulHusnaScreen extends ConsumerStatefulWidget {
  const AsmaulHusnaScreen({super.key});

  @override
  ConsumerState<AsmaulHusnaScreen> createState() => _AsmaulHusnaScreenState();
}

class _AsmaulHusnaScreenState extends ConsumerState<AsmaulHusnaScreen> {
  bool _hafalan = false;

  /// Cards whose meaning was revealed in Hafalan mode.
  final Set<int> _revealed = {};

  Future<void> _refresh() async {
    ref.read(husnaRefreshProvider.notifier).state++;
    try {
      await ref.read(husnaListProvider.future);
    } catch (_) {
      // The error state offers "Coba lagi".
    }
  }

  void _setHafalan(bool value) => setState(() {
    _hafalan = value;
    _revealed.clear();
  });

  @override
  Widget build(BuildContext context) {
    final names = ref.watch(husnaListProvider);
    return SenjaTabScaffold(
      title: 'Asmaul Husna',
      subtitle: '99 nama Allah',
      hero: 'images/3d/icon_husna.webp',
      heroWidth: 124,
      heroTop: 34,
      heroRight: 18,
      body: names.when(
        skipLoadingOnReload: true,
        data: _content,
        loading: () => const SenjaSkeletonList(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
        ),
        error: (_, _) => SenjaEmptyState(
          image: 'images/3d/icon_husna.webp',
          badgeIcon: Icons.wifi_off_rounded,
          title: 'Asmaul Husna belum tersimpan',
          message:
              'Buka sekali saat ada internet. Setelah itu 99 nama Allah bisa '
              'dibuka kapan saja, tanpa kuota.',
          primaryLabel: 'Coba lagi',
          onPrimary: _refresh,
        ),
      ),
    );
  }

  Widget _content(Cached<List<HusnaName>> cached) {
    final names = cached.data;
    if (names.isEmpty) return const SizedBox.shrink();
    final offline = cached.offline || ref.watch(networkStatusProvider);
    final today = ref.watch(
      clockProvider.select((clock) {
        final now = clock.valueOrNull ?? DateTime.now();
        return DateTime(now.year, now.month, now.day);
      }),
    );
    final daily = nameOfTheDay(names, today);
    final cardHeight = MediaQuery.textScalerOf(context).scale(132);

    return RefreshIndicator(
      color: AppColors.secondary,
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            sliver: SliverList.list(
              children: [
                if (offline) ...[
                  OfflineBanner(
                    message:
                        'Asmaul Husna tetap bisa dibuka dari data tersimpan.',
                    savedAt: cached.savedAt,
                    onRetry: _refresh,
                  ),
                  const SizedBox(height: 14),
                ],
                HusnaTodayCard(
                  name: daily,
                  total: names.length,
                  onDzikir: () => openHusnaDzikir(context, daily),
                  onShare: () => shareHusna(daily),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SenjaSegmented(
                        items: const [
                          SenjaSegment('Semua'),
                          SenjaSegment('Hafalan'),
                        ],
                        selected: _hafalan ? 1 : 0,
                        onChanged: (i) => _setHafalan(i == 1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _QuizButton(onTap: () => openHusnaQuiz(context)),
                  ],
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: cardHeight,
              ),
              delegate: SliverChildBuilderDelegate((context, i) {
                final name = names[i];
                return HusnaNameCard(
                  name: name,
                  showMeaning: !_hafalan || _revealed.contains(name.number),
                  onTap: () {
                    if (!_hafalan) {
                      showHusnaSheet(context, name);
                      return;
                    }
                    setState(() {
                      if (!_revealed.remove(name.number)) {
                        _revealed.add(name.number);
                      }
                    });
                  },
                );
              }, childCount: names.length),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark "Kuis" button next to the Semua/Hafalan switch.
class _QuizButton extends StatelessWidget {
  const _QuizButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Kuis hafalan Asmaul Husna',
      excludeSemantics: true,
      child: Material(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            height: 46,
            padding: const EdgeInsets.only(left: 13, right: 16),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 17,
                  color: AppColors.primary,
                ),
                SizedBox(width: 6),
                Text(
                  'Kuis',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
