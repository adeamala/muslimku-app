class QuranAyahModel {
  final int nomor;
  final String arab;
  final String indo;
  final SuratInfo surat;

  QuranAyahModel({
    required this.nomor,
    required this.arab,
    required this.indo,
    required this.surat,
  });

  factory QuranAyahModel.fromJson(Map<String, dynamic> json) {
    final ayatData = (json['ayat'] ?? json) as Map<String, dynamic>;
    final infoData =
        (json['info'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    final suratData =
        (infoData['surat'] ?? <String, dynamic>{}) as Map<String, dynamic>;

    return QuranAyahModel(
      nomor: int.tryParse(ayatData['ayah']?.toString() ?? '0') ?? 0,
      arab: (ayatData['arab'] ?? '') as String,
      indo: (ayatData['text'] ?? ayatData['indo'] ?? '') as String,
      surat: SuratInfo.fromJson(suratData),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nomor': nomor,
      'arab': arab,
      'indo': indo,
      'surat': surat.toJson(),
    };
  }
}

class SuratInfo {
  final int nomor;
  final String nama;
  final String namaLatin;
  final int jumlahAyat;

  SuratInfo({
    required this.nomor,
    required this.nama,
    required this.namaLatin,
    required this.jumlahAyat,
  });

  factory SuratInfo.fromJson(Map<String, dynamic> json) {
    return SuratInfo(
      nomor: (json['id'] ?? json['nomor'] ?? 0) as int,
      // `nama` is {ar, id, en} in quran/ayat/acak and a plain string elsewhere.
      nama: switch (json['nama']) {
        {'ar': final String ar} => ar,
        final String name => name,
        _ => '',
      },
      namaLatin: switch (json['nama']) {
        {'id': final String latin} => latin,
        _ => (json['nama_latin'] ?? '') as String,
      },
      jumlahAyat: (json['jumlah_ayat'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nomor': nomor,
      'nama': nama,
      'nama_latin': namaLatin,
      'jumlah_ayat': jumlahAyat,
    };
  }
}
