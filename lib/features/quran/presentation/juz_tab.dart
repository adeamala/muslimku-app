import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/quran/application/khatam_plan_provider.dart';
import 'package:muslimku/features/quran/application/quran_progress_provider.dart';
import 'package:muslimku/features/quran/data/quran_repository.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/features/quran/presentation/khatam_plan_sheet.dart';
import 'package:muslimku/features/quran/presentation/quran_list_logic.dart';
import 'package:muslimku/features/quran/presentation/quran_list_shared.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

const _limeRing = Color(0xFF9BB800);

/// "Juz" tab (design `q2`): "Progres khatam" and the 30 juz in two columns.
/// A juz opens the reader at its first ayah; a long press marks it finished.
class JuzTab extends ConsumerWidget {
  const JuzTab({super.key, required this.onTab});

  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final juzList = ref.watch(juzListProvider);
    final done = ref.watch(khatamProvider);
    final lastRead = ref.watch(lastReadProvider);
    final offline = ref.watch(quranOfflineProvider);
    Future<void> refresh() {
      final container = ProviderScope.containerOf(context, listen: false);
      return Future.wait([
        refreshJuzList(container),
        refreshSurahList(container),
      ]);
    }

    return RefreshIndicator(
      onRefresh: refresh,
      color: AppColors.secondary,
      child: CustomScrollView(
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          quranTopSliver([
            if (offline) const OfflineBanner(message: quranOfflineMessage),
          ]),
          quranTabBarSliver(selected: QuranTabs.juz, onChanged: onTab),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            sliver: SliverToBoxAdapter(
              child: KhatamCard(done: done, lastRead: lastRead),
            ),
          ),
          ..._grid(context, ref, juzList, done),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  List<Widget> _grid(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Cached<List<JuzInfo>>> juzList,
    Set<int> done,
  ) {
    final juz = juzList.valueOrNull?.data;
    if (juz == null) {
      if (juzList.hasError && !juzList.isLoading) {
        return [
          SliverToBoxAdapter(
            child: SenjaEmptyState(
              image: 'images/3d/icon_quran.webp',
              badgeIcon: Icons.wifi_off_rounded,
              title: 'Daftar juz belum bisa dimuat',
              message: 'Periksa internet lalu coba lagi.',
              primaryLabel: 'Coba lagi',
              onPrimary: () => ref.invalidate(juzListProvider),
            ),
          ),
        ];
      }
      return const [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(child: SenjaSkeletonList(rows: 4)),
        ),
      ];
    }
    Widget card(JuzInfo j) => JuzCard(
      juz: j,
      done: done.contains(j.number),
      onTap: () => openQuranReader(context, j.startSurah, ayah: j.startVerse),
      onLongPress: () => _toggleDone(context, ref, j.number),
    );
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList.builder(
          itemCount: (juz.length + 1) ~/ 2,
          itemBuilder: (context, row) {
            final left = juz[row * 2];
            final right = row * 2 + 1 < juz.length ? juz[row * 2 + 1] : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: card(left)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: right == null ? const SizedBox() : card(right),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  void _toggleDone(BuildContext context, WidgetRef ref, int juz) {
    final khatam = ref.read(khatamProvider.notifier);
    final wasDone = ref.read(khatamProvider).contains(juz);
    void apply(bool markDone) =>
        markDone ? khatam.markDone(juz) : khatam.unmark(juz);
    apply(!wasDone);
    showUndoSnackBar(
      context,
      wasDone ? 'Tanda selesai Juz $juz dihapus' : 'Juz $juz ditandai selesai',
      () => apply(wasDone),
    );
  }
}

/// "Progres khatam": finished juz out of 30, a tick per juz (purple when
/// finished, lime for the juz being read) and "Sedang dibaca".
class KhatamCard extends ConsumerWidget {
  const KhatamCard({super.key, required this.done, required this.lastRead});

  final Set<int> done;
  final LastRead? lastRead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final read = lastRead;
    final count = khatamDoneCount(done);
    final ticks = khatamTicks(done, currentJuz: read?.juz);
    final plan = ref.watch(khatamPlanProvider);
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final status = plan?.status(doneJuz: count, today: now);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.stageBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lilacLine, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'Progres khatam',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count dari 30 juz',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            label: '$count dari 30 juz selesai',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 0; i < ticks.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(child: _Tick(ticks[i])),
                  ],
                ],
              ),
            ),
          ),
          if (read != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _limeRing,
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      text: 'Sedang dibaca:  ',
                      children: [
                        TextSpan(
                          text: readingNowLabel(read),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (plan == null || status == null)
            Align(
              alignment: Alignment.centerLeft,
              child: SenjaSmallButton(
                label: 'Buat rencana',
                onTap: () => showKhatamPlanSheet(context),
              ),
            )
          else
            Semantics(
              button: true,
              label: '${plan.label}, ${status.line}, ubah rencana',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => showKhatamPlanSheet(context),
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.lilacLine),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          status.finished
                              ? Icons.celebration_rounded
                              : status.behind > 0
                              ? Icons.flag_rounded
                              : Icons.flag_outlined,
                          size: 18,
                          color: status.behind > 0
                              ? AppColors.offlineAccent
                              : AppColors.secondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              Text(
                                status.line,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: AppColors.secondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick(this.state);

  final KhatamTick state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: switch (state) {
          KhatamTick.done => AppColors.secondary,
          KhatamTick.current => AppColors.primary,
          KhatamTick.pending => AppColors.lilacLine,
        },
        borderRadius: BorderRadius.circular(3),
        border: state == KhatamTick.current
            ? Border.all(color: _limeRing, width: 1.5)
            : null,
      ),
    );
  }
}

/// One juz (design `.jc`): number, a check when finished, its opening words
/// in Arabic and the ayah range.
class JuzCard extends StatelessWidget {
  const JuzCard({
    super.key,
    required this.juz,
    required this.done,
    required this.onTap,
    this.onLongPress,
  });

  final JuzInfo juz;
  final bool done;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Juz ${juz.number}${done ? ', selesai' : ''}',
      hint: 'Tahan untuk menandai selesai',
      child: GestureDetector(
        onLongPress: onLongPress,
        child: SenjaCard(
          onTap: onTap,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 22),
                child: Row(
                  children: [
                    Expanded(
                      child: ExcludeSemantics(
                        child: Text(
                          'Juz ${juz.number}',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.25,
                            letterSpacing: 0,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                    if (done)
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              ExcludeSemantics(
                child: ArabicText(
                  juz.opening,
                  size: 19,
                  height: 1.6,
                  color: AppColors.secondary,
                  maxLines: 1,
                ),
              ),
              Text(
                juzRangeText(juz),
                style: TextStyle(
                  fontSize: 11.5,
                  height: 16 / 11.5,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
