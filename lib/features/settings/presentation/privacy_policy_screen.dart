import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// Shown on the page. Change it together with the copy linked in Play Console.
const privacyPolicyUpdated = '28 Oktober 2026';

class PolicySection {
  const PolicySection(this.title, this.paragraphs);

  final String title;
  final List<String> paragraphs;
}

/// Google Play wants the privacy policy inside the app as well as in Play
/// Console. The same text is in the release notes for the Play listing
/// (`PRIVACY-POLICY-<versi>.md` next to the review), so both stay identical.
const privacyPolicySections = <PolicySection>[
  PolicySection('Ringkasan', [
    'Muslimku tidak meminta akun, tidak menampilkan iklan, dan tidak memakai '
        'pelacak. Kami tidak punya server sendiri: pengaturan dan catatanmu '
        'tersimpan di HP, sedangkan konten ibadah diambil dari layanan publik.',
  ]),
  PolicySection('Data yang tersimpan di HP', [
    'Kota pilihan, pengaturan pengingat adzan, dan tampilan baca.',
    'Penanda ayat, hadits, dan doa; terakhir dibaca; progres khatam; dan '
        'progres hafalan Asmaul Husna.',
    'Salinan teks dan jadwal yang sudah dimuat, supaya bisa dibuka tanpa '
        'internet.',
    'Semua ini hanya ada di HP-mu dan tidak dikirim ke mana pun. Untuk '
        'menghapusnya, buka Setelan Android → Aplikasi → Muslimku → '
        'Penyimpanan → Hapus data, atau copot aplikasinya.',
  ]),
  PolicySection('Lokasi', [
    'Izin lokasi perkiraan (bukan lokasi persis) hanya diminta saat kamu '
        'menekan "Pakai lokasi saya" atau membuka Kiblat.',
    'Posisimu diolah di HP untuk memilih kota terdekat dari daftar di dalam '
        'aplikasi dan menghitung arah kiblat. Koordinatnya tidak disimpan dan '
        'tidak dikirim; yang disimpan hanya kota yang terpilih.',
    'Sensor kompas untuk Kiblat juga hanya dipakai di HP.',
  ]),
  PolicySection('Koneksi internet', [
    'Jadwal sholat, tanggal Hijriah, Al-Qur\'an, hadits, doa, dan Asmaul Husna '
        'diambil dari API publik MyQuran (api.myquran.com). Permintaannya '
        'berisi nomor kota (atau nama kota yang kamu ketik saat mencari) dan '
        'tanggal.',
    'Audio murottal diputar dari cdn.islamic.network; surat yang diunduh '
        'lewat "Murottal offline" tersimpan di HP dan bisa dihapus dari '
        'Pengaturan. Tafsir Kemenag diambil '
        'dari equran.id dan teks tajwid dari alquran.cloud saat pertama dibuka, '
        'lalu tersimpan di HP.',
    'Semua koneksi memakai HTTPS (terenkripsi). Seperti layanan internet pada '
        'umumnya, server tersebut dapat melihat alamat IP perangkatmu. '
        'Muslimku tidak mengirim data lain tentang dirimu.',
  ]),
  PolicySection('Pengingat adzan', [
    'Jika kamu menyalakannya, jadwal pemberitahuan disusun dan disimpan di HP. '
        'Izin yang dipakai: notifikasi, alarm tepat waktu (agar adzan tidak '
        'terlambat), memasang ulang pengingat setelah HP dinyalakan ulang, dan '
        'getar.',
    'Suara pengingat (adzan, bedug, dan lainnya) ada di dalam aplikasi dan '
        'diputar tanpa internet. Halaman "Cek pengingat" hanya membaca status '
        'izin dan penghemat baterai di HP; tidak ada yang dikirim.',
  ]),
  PolicySection('Catatan sholat, kalender, dan widget', [
    'Tanda "Sudah sholat" dan rangkaian harimu disimpan hanya di HP ini, '
        'tanpa akun dan tanpa dikirim ke mana pun. Menghapus data aplikasi '
        'menghapusnya.',
    'Kalender Hijriah dan hari besar dihitung di HP (hisab). Widget layar '
        'utama membaca jadwal yang sudah tersimpan di HP.',
  ]),
  PolicySection('Berbagi dan menyalin', [
    'Saat kamu menekan Bagikan atau Salin, teks atau gambar diteruskan ke '
        'aplikasi yang kamu pilih lewat menu Android. Muslimku tidak menyimpan '
        'dan tidak melihat apa yang kamu bagikan.',
  ]),
  PolicySection('Iklan, analitik, dan pihak lain', [
    'Muslimku tidak memuat iklan, analitik, pelaporan crash, atau pelacak '
        'lain. Kami tidak menjual data dan tidak memberikan data kepada pihak '
        'lain selain permintaan ke layanan yang disebut di atas.',
  ]),
  PolicySection('Anak-anak', [
    'Muslimku aman dipakai semua umur dan tidak mengumpulkan data pribadi '
        'siapa pun, termasuk anak-anak.',
  ]),
  PolicySection('Perubahan kebijakan', [
    'Jika cara Muslimku memakai data berubah, kebijakan ini diperbarui di '
        'halaman ini dan di tautan kebijakan privasi di Google Play.',
  ]),
  PolicySection('Kontak', [
    'PT Sahabat Sejahtera Jayati',
    'developer.cvai@gmail.com',
  ]),
];

/// Kebijakan privasi, opened from Pengaturan > Tentang. Plain text, so it
/// also reads offline; the text can be selected to copy the e-mail address.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.stageBackground,
        body: DefaultTextStyle(
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 14,
            height: 1.55,
            letterSpacing: 0,
            fontWeight: FontWeight.w500,
            color: AppColors.ink,
          ),
          child: SelectionArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, top + 4, 16, bottom + 28),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SenjaIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Kembali',
                    iconSize: 24,
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 2),
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Kebijakan privasi',
                      style: TextStyle(
                        fontSize: 30,
                        height: 1.15,
                        letterSpacing: -0.6,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 16),
                  child: Text(
                    'Terakhir diperbarui $privacyPolicyUpdated',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
                for (final section in privacyPolicySections)
                  _SectionCard(section),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard(this.section);

  final PolicySection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lilacLine, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              section.title,
              style: TextStyle(
                fontSize: 15.5,
                height: 1.3,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          for (final paragraph in section.paragraphs) ...[
            const SizedBox(height: 8),
            Text(paragraph),
          ],
        ],
      ),
    );
  }
}
