class PrayerTimeModel {
  final String id;
  final String lokasi;
  final String daerah;
  final PrayerSchedule jadwal;

  PrayerTimeModel({
    required this.id,
    required this.lokasi,
    required this.daerah,
    required this.jadwal,
  });

  /// The same city with another day, e.g. after `PrayerOffsets.apply`.
  PrayerTimeModel withJadwal(PrayerSchedule day) =>
      PrayerTimeModel(id: id, lokasi: lokasi, daerah: daerah, jadwal: day);

  factory PrayerTimeModel.fromJson(Map<String, dynamic> json) {
    return PrayerTimeModel(
      id: json['id'].toString(),
      lokasi: (json['lokasi'] ?? '') as String,
      daerah: (json['daerah'] ?? '') as String,
      jadwal: PrayerSchedule.fromJson(
        (json['jadwal'] ?? <String, dynamic>{}) as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lokasi': lokasi,
      'daerah': daerah,
      'jadwal': jadwal.toJson(),
    };
  }
}

class PrayerSchedule {
  final String tanggal;
  final String imsak;
  final String subuh;
  final String terbit;
  final String dhuha;
  final String dzuhur;
  final String ashar;
  final String maghrib;
  final String isya;
  final String date;

  PrayerSchedule({
    required this.tanggal,
    required this.imsak,
    required this.subuh,
    required this.terbit,
    required this.dhuha,
    required this.dzuhur,
    required this.ashar,
    required this.maghrib,
    required this.isya,
    required this.date,
  });

  factory PrayerSchedule.fromJson(Map<String, dynamic> json) {
    return PrayerSchedule(
      tanggal: (json['tanggal'] ?? '') as String,
      imsak: (json['imsak'] ?? '') as String,
      subuh: (json['subuh'] ?? '') as String,
      terbit: (json['terbit'] ?? '') as String,
      dhuha: (json['dhuha'] ?? '') as String,
      dzuhur: (json['dzuhur'] ?? '') as String,
      ashar: (json['ashar'] ?? '') as String,
      maghrib: (json['maghrib'] ?? '') as String,
      isya: (json['isya'] ?? '') as String,
      date: (json['date'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tanggal': tanggal,
      'imsak': imsak,
      'subuh': subuh,
      'terbit': terbit,
      'dhuha': dhuha,
      'dzuhur': dzuhur,
      'ashar': ashar,
      'maghrib': maghrib,
      'isya': isya,
      'date': date,
    };
  }

  List<PrayerTime> get prayerTimes => [
    PrayerTime(name: 'Imsak', time: imsak, type: PrayerType.imsak),
    PrayerTime(name: 'Shubuh', time: subuh, type: PrayerType.subuh),
    PrayerTime(name: 'Fajar', time: terbit, type: PrayerType.fajar),
    PrayerTime(name: 'Dhuhur', time: dzuhur, type: PrayerType.dhuhur),
    PrayerTime(name: 'Ashar', time: ashar, type: PrayerType.ashar),
    PrayerTime(name: 'Magrib', time: maghrib, type: PrayerType.maghrib),
    PrayerTime(name: 'Isya\'', time: isya, type: PrayerType.isya),
  ];
}

class PrayerTime {
  final String name;
  final String time;
  final PrayerType type;

  PrayerTime({required this.name, required this.time, required this.type});
}

enum PrayerType {
  imsak,
  subuh,
  fajar,
  dhuhur,
  ashar,
  maghrib,
  isya;

  String get iconPath {
    switch (this) {
      case PrayerType.imsak:
        return 'images/imsak.webp';
      case PrayerType.subuh:
        return 'images/shubuh.webp';
      case PrayerType.fajar:
        return 'images/fajar.webp';
      case PrayerType.dhuhur:
        return 'images/dhuhur.webp';
      case PrayerType.ashar:
        return 'images/ashar.webp';
      case PrayerType.maghrib:
        return 'images/magrib.webp';
      case PrayerType.isya:
        return 'images/isya.webp';
    }
  }
}
