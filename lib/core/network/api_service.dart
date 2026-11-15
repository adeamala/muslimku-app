import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Client of MyQuran API v2 (plus raw JSON from other hosts). Returns the
/// decoded `data` of each endpoint; features turn it into their models.
class ApiService {
  static const String _baseUrl = 'https://api.myquran.com/v2/';

  final Dio _dio;

  ApiService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          // A connection that is not up in 15 s will not come; saved data takes over.
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        ),
      );

  // Prayer Times
  Future<Map<String, dynamic>?> getPrayerTimes(
    String cityId,
    String date,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'sholat/jadwal/$cityId/$date',
      );

      if (response.data!['status'] == true) {
        return response.data!['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get prayer times: $e');
    }
  }

  // Hijri date with MyQuran's Indonesian adjustment, e.g. "13 Jumadil Awal 1448 H".

  Future<List<Map<String, dynamic>>?> searchCities(String keyword) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'sholat/kota/cari/$keyword',
      );

      if (response.data!['status'] == true) {
        return List<Map<String, dynamic>>.from(
          response.data!['data'] as Iterable<dynamic>,
        );
      }
      return null;
    } catch (e) {
      throw Exception('Failed to search cities: $e');
    }
  }

  // Quran
  Future<Map<String, dynamic>?> getRandomQuranAyah() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('quran/ayat/acak');

      if (response.data!['status'] == true) {
        return response.data!['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get random Quran ayah: $e');
    }
  }

  // Hadith
  Future<Map<String, dynamic>?> getRandomHadithArbain() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'hadits/arbain/acak',
      );

      if (response.data!['status'] == true) {
        return response.data!['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get random Hadith Arbain: $e');
    }
  }

  Future<Map<String, dynamic>?> getRandomHadithBulughulMaram() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('hadits/bm/acak');

      if (response.data!['status'] == true) {
        return response.data!['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get random Hadith Bulughul Maram: $e');
    }
  }

  Future<Map<String, dynamic>?> getRandomHadithPerawi() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'hadits/perawi/acak',
      );

      if (response.data!['status'] == true) {
        return response.data!['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get random Hadith Perawi: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllHadithArbain() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'hadits/arbain/semua',
      );

      if (response.data!['status'] == true && response.data!['data'] != null) {
        return List<Map<String, dynamic>>.from(
          response.data!['data'] as Iterable<dynamic>,
        );
      }
      return const [];
    } catch (e) {
      throw Exception('Failed to get all Hadith Arbain: $e');
    }
  }

  Future<Map<String, dynamic>?> getHadithBulughulByNumber(int number) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'hadits/bm/$number',
      );

      if (response.data!['data'] != null) {
        return Map<String, dynamic>.from(
          response.data!['data'] as Map<dynamic, dynamic>,
        );
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get Hadith Bulughul Maram: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPerawiList() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('hadits/perawi');

      if (response.data!['data'] != null) {
        return List<Map<String, dynamic>>.from(
          response.data!['data'] as Iterable<dynamic>,
        );
      }
      return const [];
    } catch (e) {
      throw Exception('Failed to get perawi list: $e');
    }
  }

  Future<Map<String, dynamic>?> getHadithByPerawi(
    String slug,
    int number,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'hadits/$slug/$number',
      );

      if (response.data!['data'] != null) {
        return Map<String, dynamic>.from(
          response.data!['data'] as Map<dynamic, dynamic>,
        );
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get hadith by perawi $slug: $e');
    }
  }

  // Asmaul Husna
  Future<Map<String, dynamic>?> getRandomAsmaulHusna() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('husna/acak');

      if (response.data!['status'] == true) {
        return response.data!['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get random Asmaul Husna: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllAsmaulHusna() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('husna/semua');

      if (response.data!['status'] == true && response.data!['data'] != null) {
        return List<Map<String, dynamic>>.from(
          response.data!['data'] as Iterable<dynamic>,
        );
      }
      return const [];
    } catch (e) {
      throw Exception('Failed to get Asmaul Husna list: $e');
    }
  }

  // Doa
  Future<Map<String, dynamic>?> getRandomDoa() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('doa/acak');

      if (response.data!['status'] == true) {
        return response.data!['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get random Doa: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllDoa() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('doa/semua');

      if (response.data!['status'] == true && response.data!['data'] != null) {
        return List<Map<String, dynamic>>.from(
          response.data!['data'] as Iterable<dynamic>,
        );
      }
      return const [];
    } catch (e) {
      throw Exception('Failed to get doa list: $e');
    }
  }

  // Al-Quran Lists
  Future<List<Map<String, dynamic>>?> getAllSurat() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'quran/surat/semua',
      );

      if (response.data!['status'] == true) {
        return List<Map<String, dynamic>>.from(
          response.data!['data'] as Iterable<dynamic>,
        );
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get all surat: $e');
    }
  }

  Future<List<Map<String, dynamic>>?> getAllJuz() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('quran/juz/semua');

      if (response.data!['status'] == true) {
        return List<Map<String, dynamic>>.from(
          response.data!['data'] as Iterable<dynamic>,
        );
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get all juz: $e');
    }
  }

  Future<Map<String, dynamic>?> getSuratDetail(int suratNumber) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'quran/surat/$suratNumber',
      );

      if (response.data!['status'] == true) {
        return response.data!['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get surat detail: $e');
    }
  }

  Future<Map<String, dynamic>?> getJuzDetail(int juzNumber) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'quran/juz/$juzNumber',
      );

      final data = response.data!['data'];
      if (data != null) {
        return Map<String, dynamic>.from(data as Map<dynamic, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get juz detail: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAyatBySurat({
    required int suratNumber,
    required int totalAyat,
  }) async {
    try {
      if (totalAyat <= 0) {
        return const <Map<String, dynamic>>[];
      }

      const int batchSize = 30;
      final List<Map<String, dynamic>> verses = [];

      for (int start = 1; start <= totalAyat; start += batchSize) {
        final int end = math.min(totalAyat, start + batchSize - 1);
        final response = await _dio.get<Map<String, dynamic>>(
          'quran/ayat/$suratNumber/$start-$end',
        );

        if (response.data!['status'] == true) {
          final batch = List<Map<String, dynamic>>.from(
            response.data!['data'] as Iterable<dynamic>,
          );
          verses.addAll(batch);
        } else {
          final errorMessage = response.data!['message'] ?? 'Unknown error';
          throw Exception('Failed to get ayat $start-$end: $errorMessage');
        }
      }

      return verses;
    } catch (e) {
      throw Exception('Failed to get ayat by surat: $e');
    }
  }

  Future<List<Map<String, dynamic>>?> getAyatByJuz(int juzNumber) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'quran/ayat/juz/$juzNumber',
      );

      if (response.data!['status'] == true) {
        return List<Map<String, dynamic>>.from(
          response.data!['data'] as Iterable<dynamic>,
        );
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get ayat by juz: $e');
    }
  }

  /// The decoded body of a JSON endpoint on another host (equran.id,
  /// alquran.cloud). Same timeouts as MyQuran; throws on failure.
  Future<dynamic> getExternalJson(String url) async {
    final response = await _dio.get(url);
    return response.data;
  }

  /// The `data` field of any MyQuran v2 endpoint, e.g. `getJson('hadits/bm/12')`.
  /// Throws when the request fails or MyQuran answers `status: false`.
  Future<dynamic> getJson(String path) async {
    final response = await _dio.get(path);
    final body = response.data;
    if (body is Map) {
      if (body['status'] == false) {
        throw Exception(
          'MyQuran: ${body['message'] ?? 'status false'} ($path)',
        );
      }
      return body['data'];
    }
    return body;
  }
}

/// The MyQuran client. Tests override it with a fake.
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
