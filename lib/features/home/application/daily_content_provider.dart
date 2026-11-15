import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/asmaul_husna/domain/asmaul_husna_model.dart';
import 'package:muslimku/features/doa/domain/doa_model.dart';
import 'package:muslimku/features/hadith/domain/hadith_model.dart';
import 'package:muslimku/features/quran/domain/quran_ayah_model.dart';

final dailyContentProvider =
    NotifierProvider<DailyContentNotifier, DailyContentState>(
      DailyContentNotifier.new,
    );

class DailyContentState {
  final QuranAyahModel? quranAyah;
  final HadithArbainModel? hadithArbain;
  final HadithModel? hadithBulughul;
  final HadithModel? hadithPerawi;
  final AsmaulHusnaModel? asmaulHusna;
  final DoaModel? doa;
  final bool isLoading;
  final String? error;
  final int currentHour;

  DailyContentState({
    this.quranAyah,
    this.hadithArbain,
    this.hadithBulughul,
    this.hadithPerawi,
    this.asmaulHusna,
    this.doa,
    this.isLoading = false,
    this.error,
    this.currentHour = 0,
  });

  DailyContentState copyWith({
    QuranAyahModel? quranAyah,
    HadithArbainModel? hadithArbain,
    HadithModel? hadithBulughul,
    HadithModel? hadithPerawi,
    AsmaulHusnaModel? asmaulHusna,
    DoaModel? doa,
    bool? isLoading,
    String? error,
    int? currentHour,
  }) {
    return DailyContentState(
      quranAyah: quranAyah ?? this.quranAyah,
      hadithArbain: hadithArbain ?? this.hadithArbain,
      hadithBulughul: hadithBulughul ?? this.hadithBulughul,
      hadithPerawi: hadithPerawi ?? this.hadithPerawi,
      asmaulHusna: asmaulHusna ?? this.asmaulHusna,
      doa: doa ?? this.doa,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      currentHour: currentHour ?? this.currentHour,
    );
  }
}

class DailyContentNotifier extends Notifier<DailyContentState> {
  late ApiService _apiService;

  @override
  DailyContentState build() {
    _apiService = ref.read(apiServiceProvider);
    // State can only change once build has returned.
    Future.microtask(_checkAndLoadHourlyContent);
    return DailyContentState(currentHour: ref.read(nowProvider)().hour);
  }

  Future<void> _checkAndLoadHourlyContent() async {
    final currentHour = ref.read(nowProvider)().hour;

    if (state.currentHour != currentHour || _isContentEmpty()) {
      state = state.copyWith(currentHour: currentHour);
      await _loadHourlyContent();
    }
  }

  bool _isContentEmpty() {
    return state.quranAyah == null &&
        state.hadithArbain == null &&
        state.hadithBulughul == null &&
        state.hadithPerawi == null &&
        state.asmaulHusna == null &&
        state.doa == null;
  }

  // The cards are fetched on every load. Nothing was ever written under the
  // per-hour keys this used to read, so that check never found a copy.
  Future<void> _loadHourlyContent() => _loadContentDirectly();

  Future<void> loadQuranAyah() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final json = await _apiService.getRandomQuranAyah();
      final ayah = json == null ? null : QuranAyahModel.fromJson(json);
      state = state.copyWith(quranAyah: ayah, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat konten harian',
      );
    }
  }

  Future<void> loadHadithArbain() async {
    try {
      final json = await _apiService.getRandomHadithArbain();
      final hadith = json == null ? null : HadithArbainModel.fromJson(json);
      state = state.copyWith(hadithArbain: hadith);
    } catch (e) {
      state = state.copyWith(error: 'Gagal memuat konten harian');
    }
  }

  Future<void> loadHadithBulughul() async {
    try {
      final json = await _apiService.getRandomHadithBulughulMaram();
      final hadith = json == null ? null : HadithModel.fromJson(json);
      state = state.copyWith(hadithBulughul: hadith);
    } catch (e) {
      state = state.copyWith(error: 'Gagal memuat konten harian');
    }
  }

  Future<void> loadHadithPerawi() async {
    try {
      final json = await _apiService.getRandomHadithPerawi();
      final hadith = json == null ? null : HadithModel.fromJson(json);
      state = state.copyWith(hadithPerawi: hadith);
    } catch (e) {
      state = state.copyWith(error: 'Gagal memuat konten harian');
    }
  }

  Future<void> loadAsmaulHusna() async {
    try {
      final json = await _apiService.getRandomAsmaulHusna();
      final asmaul = json == null ? null : AsmaulHusnaModel.fromJson(json);
      state = state.copyWith(asmaulHusna: asmaul);
    } catch (e) {
      state = state.copyWith(error: 'Gagal memuat konten harian');
    }
  }

  Future<void> loadDoa() async {
    try {
      final json = await _apiService.getRandomDoa();
      final doa = json == null ? null : DoaModel.fromJson(json);
      state = state.copyWith(doa: doa);
    } catch (e) {
      state = state.copyWith(error: 'Gagal memuat konten harian');
    }
  }

  Future<void> loadAllContent() async {
    await _checkAndLoadHourlyContent();
  }

  Future<void> checkHourlyUpdate() async {
    await _checkAndLoadHourlyContent();
  }

  Future<void> _loadContentDirectly() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await Future.wait([
        loadQuranAyah(),
        loadHadithArbain(),
        loadHadithBulughul(),
        loadHadithPerawi(),
        loadAsmaulHusna(),
        loadDoa(),
      ]);

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat konten harian',
      );
    }
  }
}
