import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/storage/content_cache.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/quran/data/quran_repository.dart';
import 'package:muslimku/features/quran/data/quran_themes_repository.dart';
import 'package:muslimku/features/quran/presentation/quran_list_shared.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// "Tema" tab: MyQuran's thematic index of the Qur'an (1 121 entries),
/// filtered as you type. A theme opens [ThemeAyatScreen].
class ThemesTab extends ConsumerStatefulWidget {
  const ThemesTab({super.key, required this.onTab});

  final ValueChanged<int> onTab;

  @override
  ConsumerState<ThemesTab> createState() => _ThemesTabState();
}

class _ThemesTabState extends ConsumerState<ThemesTab> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      await ref.read(quranThemesRepositoryProvider).themes(refresh: true);
    } catch (_) {
      return;
    }
    ref.invalidate(quranThemesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final themes = ref.watch(quranThemesProvider);
    final offline = ref.watch(quranOfflineProvider);
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.secondary,
      child: CustomScrollView(
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          quranTopSliver([
            if (offline) const OfflineBanner(message: quranOfflineMessage),
            SenjaSearchField(
              hint: 'Cari tema, mis. sabar, zakat, hijrah',
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              trailing: _query.trim().isEmpty
                  ? null
                  : SenjaIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Hapus teks pencarian',
                      color: AppColors.inkMuted,
                      iconSize: 19,
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ]),
          quranTabBarSliver(selected: QuranTabs.tema, onChanged: widget.onTab),
          ..._list(themes),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  List<Widget> _list(AsyncValue<Cached<List<QuranTheme>>> themes) {
    final all = themes.valueOrNull?.data;
    if (all == null) {
      if (themes.hasError && !themes.isLoading) {
        return [
          SliverToBoxAdapter(
            child: SenjaEmptyState(
              image: 'images/3d/icon_quran.webp',
              badgeIcon: Icons.wifi_off_rounded,
              title: 'Indeks tema belum tersimpan',
              message:
                  'Indeks tema diunduh sekali saat ada internet, '
                  'lalu bisa dibuka tanpa internet.',
              primaryLabel: 'Coba lagi',
              onPrimary: () => ref.invalidate(quranThemesProvider),
            ),
          ),
        ];
      }
      return const [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(child: SenjaSkeletonList()),
        ),
      ];
    }
    final shown = [
      for (final t in all)
        if (t.matches(_query)) t,
    ];
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
        sliver: SliverToBoxAdapter(
          child: Text(
            '${_thousands(shown.length)} tema',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.inkMuted,
            ),
          ),
        ),
      ),
      if (shown.isEmpty)
        const SliverToBoxAdapter(
          child: SenjaEmptyState(
            image: 'images/3d/icon_quran.webp',
            title: 'Tema tidak ditemukan',
            message: 'Coba kata lain, mis. "sabar" atau "zakat".',
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: shown.length,
            itemBuilder: (context, i) {
              final theme = shown[i];
              return SenjaListRow(
                leading: OctagramBadge('${theme.id}'),
                title: theme.name,
                titleMaxLines: 3, // long theme names at 130% text
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ThemeAyatScreen(theme: theme),
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.secondary,
                ),
              );
            },
          ),
        ),
    ];
  }

  /// "1.121" (Indonesian thousands separator).
  static String _thousands(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]}.',
  );
}

/// The ayat of one theme: Arabic, translation, and the surah · ayah which
/// opens the reader there.
class ThemeAyatScreen extends ConsumerWidget {
  const ThemeAyatScreen({super.key, required this.theme});

  final QuranTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ayat = ref.watch(themeAyatProvider(theme.id));
    final surahs = ref.watch(surahListProvider).valueOrNull?.data;
    String nameOf(int surah) =>
        surahs?.where((s) => s.number == surah).firstOrNull?.name ??
        'Surat $surah';
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.stageBackground,
      body: QuranTextDefaults(
        child: Column(
          children: [
            SenjaDetailAppBar(
              title: 'Tema ${theme.id}',
              subtitle: ayat.valueOrNull == null
                  ? 'Indeks tema Al-Qur\'an'
                  : '${ayat.valueOrNull!.data.length} ayat',
              background: AppColors.stageBackground,
            ),
            Expanded(
              child: ayat.when(
                skipLoadingOnRefresh: false,
                data: (data) => ListView(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, bottom + 28),
                  children: [
                    Text(
                      theme.name,
                      style: TextStyle(
                        fontSize: 22,
                        height: 1.25,
                        letterSpacing: -0.3,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final a in data.data) ...[
                      SenjaCard(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              button: true,
                              label:
                                  '${nameOf(a.surah)} ayat ${a.number}, '
                                  'buka di halaman baca',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => openQuranReader(
                                  context,
                                  a.surah,
                                  ayah: a.number,
                                ),
                                child: ExcludeSemantics(
                                  child: Row(
                                    children: [
                                      OctagramBadge('${a.number}'),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '${nameOf(a.surah)} · ${a.number}',
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.secondary,
                                          ),
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
                            const SizedBox(height: 10),
                            ArabicText(a.arab, size: 24, height: 2.0),
                            const SizedBox(height: 8),
                            Text(
                              a.translation,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.55,
                                fontWeight: FontWeight.w500,
                                color: AppColors.bodyText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: SenjaSkeletonList(rows: 6),
                ),
                error: (_, _) => SenjaEmptyState(
                  image: 'images/3d/icon_quran.webp',
                  badgeIcon: Icons.wifi_off_rounded,
                  title: 'Ayat tema belum tersimpan',
                  message:
                      'Buka sekali saat ada internet; setelah itu '
                      'tersimpan di HP.',
                  primaryLabel: 'Coba lagi',
                  onPrimary: () => ref.invalidate(themeAyatProvider(theme.id)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
