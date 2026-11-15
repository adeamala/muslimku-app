import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/features/doa/domain/doa_model.dart';
import 'package:muslimku/features/hadith/domain/hadith_model.dart';

/// Shapes copied from the live MyQuran v2 random endpoints.
void main() {
  test('doa/acak uses "doa" and "artinya"', () {
    final doa = DoaModel.fromJson(const {
      'id': '',
      'doa': 'اَلْحَمْدُ ِللهِ',
      'ayat': '',
      'latin': '',
      'artinya': 'Segala puji bagi Allah',
      'judul': 'Doa Ketika Mimpi Baik',
      'source': 'harian',
    });
    expect(doa.arab, 'اَلْحَمْدُ ِللهِ');
    expect(doa.indo, 'Segala puji bagi Allah');
    expect(doa.judul, 'Doa Ketika Mimpi Baik');
    expect(doa.id, 0);
  });

  test('hadits/bm/acak sends the number as a string', () {
    final h = HadithModel.fromJson(const {
      'no': '120',
      'ar': 'عَنْ',
      'id': 'Dari',
    });
    expect(h.nomor, 120);
    expect(h.arab, 'عَنْ');
    expect(h.indo, 'Dari');
  });

  test('hadits/perawi/acak uses "number" and "arab"', () {
    final h = HadithModel.fromJson(const {
      'number': '733',
      'arab': 'حَدَّثَنِي',
      'id': 'Telah menceritakan kepadaku',
    });
    expect(h.nomor, 733);
    expect(h.arab, 'حَدَّثَنِي');
    expect(h.indo, 'Telah menceritakan kepadaku');
  });

  test('hadits/arbain/acak uses "no" and has a title', () {
    final h = HadithArbainModel.fromJson(const {
      'arab': 'عَنْ أَبِيْ هُرَيْرَةَ',
      'indo': 'Dari Abu Hurairah',
      'judul': 'Allah Mahabaik dan Hanya Menerima yang Baik',
      'no': '10',
    });
    expect(h.nomor, 10);
    expect(h.judul, 'Allah Mahabaik dan Hanya Menerima yang Baik');
  });
}
