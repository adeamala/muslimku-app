import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/storage/local_store.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/quran/data/quran_repository.dart';
import 'package:muslimku/features/quran/domain/ayah_search.dart';
import 'package:muslimku/features/quran/domain/quran_models.dart';
import 'package:muslimku/features/quran/presentation/quran_list_shared.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// "Cari ayat di terjemahan ›" under the surah search on the Surat tab.
class AyahSearchLink extends StatelessWidget {
  const AyahSearchLink({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AyahSearchScreen()),
        ),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.lilac,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.manage_search_rounded,
                size: 20,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cari ayat di terjemahan',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
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
    );
  }
}

/// Full-text search over the translation and transliteration of the surahs
/// saved on the phone. Offline by design: nothing is sent anywhere.
class AyahSearchScreen extends ConsumerStatefulWidget {
  const AyahSearchScreen({super.key, this.initialQuery});

  /// Query to run as soon as the screen opens (optional).
  final String? initialQuery;

  @override
  ConsumerState<AyahSearchScreen> createState() => _AyahSearchScreenState();
}

class _AyahSearchScreenState extends ConsumerState<AyahSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  List<AyahSearchResult>? _results;
  bool _busy = false;
  Timer? _debounce;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery;
    if (initial != null && initial.isNotEmpty) {
      _controller.text = initial;
      _query = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    if (foldForSearch(value).length < ayahSearchMinLength) {
      setState(() {
        _results = null;
        _busy = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), _run);
  }

  Future<void> _run() async {
    final generation = ++_generation;
    setState(() => _busy = true);
    final names = <int, String>{
      for (final s
          in ref.read(surahListProvider).valueOrNull?.data ?? const <Surah>[])
        s.number: s.name,
    };
    final results = await searchSavedAyat(
      ref.read(localStoreProvider),
      _query,
      surahNames: names,
    );
    if (!mounted || generation != _generation) return;
    setState(() {
      _results = results;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stored = ref.watch(storedSurahsProvider).valueOrNull;
    final total =
        ref.watch(surahListProvider).valueOrNull?.data.length ??
        QuranRepository.totalSurahs;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final results = _results;
    return Scaffold(
      backgroundColor: AppColors.stageBackground,
      body: QuranTextDefaults(
        child: Column(
          children: [
            SenjaDetailAppBar(
              title: 'Cari ayat',
              subtitle: stored == null
                  ? 'Di surat yang tersimpan'
                  : '${stored.length} dari $total surat tersimpan',
              background: AppColors.stageBackground,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: SenjaSearchField(
                hint: 'Kata dalam terjemahan atau latin',
                controller: _controller,
                onChanged: _onChanged,
                trailing: _query.isEmpty
                    ? null
                    : SenjaIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Hapus teks pencarian',
                        color: AppColors.inkMuted,
                        iconSize: 19,
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
              ),
            ),
            Expanded(
              child: results == null
                  ? _Hint(
                      busy: _busy,
                      stored: stored?.length ?? 0,
                      total: total,
                    )
                  : results.isEmpty
                  ? SenjaEmptyState(
                      image: 'images/3d/icon_quran.webp',
                      title: 'Tidak ada ayat yang cocok',
                      message: (stored?.length ?? 0) < total
                          ? 'Pencarian hanya menjelajah surat yang tersimpan '
                                'di HP. Simpan Al-Qur\'an dari tab Surat agar '
                                'semua ayat ikut dicari.'
                          : 'Coba kata lain, mis. "sabar" atau "rezeki".',
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 24),
                      itemCount: results.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              results.length >= 200
                                  ? '200 ayat pertama ditampilkan'
                                  : '${results.length} ayat ditemukan',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          );
                        }
                        final r = results[i - 1];
                        return _ResultRow(result: r, query: _query);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.busy, required this.stored, required this.total});

  final bool busy;
  final int stored;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: SenjaSkeletonList(rows: 5),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: SenjaCard(
        child: Text(
          stored == 0
              ? 'Belum ada surat tersimpan. Buka sebuah surat atau simpan '
                    'Al-Qur\'an dari tab Surat, lalu cari di sini.'
              : 'Ketik minimal 3 huruf. Mencari di terjemahan Kemenag dan '
                    'tulisan latin dari $stored surat yang tersimpan, tanpa '
                    'internet.',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.5,
            fontWeight: FontWeight.w500,
            color: AppColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result, required this.query});

  final AyahSearchResult result;
  final String query;

  @override
  Widget build(BuildContext context) {
    final a = result.ayah;
    return SenjaListRow(
      leading: OctagramBadge('${a.number}'),
      title: '${result.surahName} · ${a.number}',
      subtitle: null,
      onTap: () => openQuranReader(context, a.surah, ayah: a.number),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.secondary,
      ),
      below: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text.rich(
          _highlighted(a.translation, query),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w500,
            color: AppColors.bodyText,
          ),
        ),
      ),
    );
  }

  static TextSpan _highlighted(String text, String query) {
    final ranges = highlightRanges(text, query);
    if (ranges.isEmpty) return TextSpan(text: text);
    final spans = <TextSpan>[];
    var at = 0;
    for (final (start, end) in ranges) {
      if (start < at) continue;
      if (start > at) spans.add(TextSpan(text: text.substring(at, start)));
      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.secondary,
          ),
        ),
      );
      at = end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(children: spans);
  }
}
