/// Qari of the murottal, streamed ayah by ayah from the Islamic Network CDN
/// (`cdn.islamic.network/quran/audio/<kbps>/<id>/<ayah>.mp3`).
///
/// The CDN publishes most reciters at 128 kbps; As-Sudais only at 192 and 64
/// (checked 26 Oct 2026), hence the bitrate per reciter.
enum Reciter {
  alafasy('Mishary Rashid Alafasy', 'Alafasy', 'ar.alafasy', 128),
  sudais('Abdurrahman As-Sudais', 'As-Sudais', 'ar.abdurrahmaansudais', 192),
  husary('Mahmoud Khalil Al-Husary', 'Al-Husary', 'ar.husary', 128),
  minshawi('Mohamed Siddiq Al-Minshawi', 'Al-Minshawi', 'ar.minshawi', 128),
  muaiqly('Maher Al-Muaiqly', 'Al-Muaiqly', 'ar.mahermuaiqly', 128);

  const Reciter(this.label, this.shortLabel, this.cdnId, this.kbps);

  /// Full name, e.g. in the murottal bar.
  final String label;

  /// Name for a chip.
  final String shortLabel;
  final String cdnId;
  final int kbps;

  /// Audio of the ayah with MyQuran/alquran.cloud id [ayahId] (1–6236).
  String url(int ayahId) =>
      'https://cdn.islamic.network/quran/audio/$kbps/$cdnId/$ayahId.mp3';

  static Reciter byName(String? name) =>
      values.where((r) => r.name == name).firstOrNull ?? alafasy;
}
