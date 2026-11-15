# Rilis ke Play Store

Muslimku (`com.muslimku.app`) bisa dirilis dari laptop mana pun **atau** dari
GitHub Actions. Keduanya memakai skrip yang sama, `tools/release/build_aab.sh`,
yang menolak AAB kalau tidak ditandatangani dengan upload key yang terdaftar.

## Kunci upload (wajib dibaca)

| | |
|---|---|
| File | `my-release-key.jks` (alias `my-key-alias`) |
| SHA-1 | `42:98:58:9D:CC:C9:6C:35:A1:9A:EE:D9:16:D5:41:32:4E:84:12:37` |
| Berlaku sejak | 8 Nov 2026 (hasil reset upload key) |

- Keystore dan kata sandinya **tidak ada di Git**. Simpan dua file ini di
  password manager / cloud pribadi:
  - `android/key.properties`
  - `android/app/keystore/my-release-key.jks`
- Kunci lama `upload-keystore.jks` (SHA-1 `C4:A4…`) **sudah tidak berlaku**.
- Kalau kunci ini hilang: Play Console → Muslimku → *Dilindungi dengan Google
  Play → Penandatanganan aplikasi → Upload kunci → Minta reset*. Bukti reset
  dikirim ke email dari `noreply-play-console@google.com`.

## Sebelum setiap rilis

Naikkan versi di `pubspec.yaml`. Angka setelah `+` (versionCode) harus lebih
besar dari rilis terakhir di Play:

```yaml
version: 1.5.2+12
```

## Cara A: build di laptop

Sekali per laptop:

1. Install Flutter lewat [fvm](https://fvm.app), lalu di folder project:
   `fvm install` (versi diambil dari `.fvmrc`).
2. Install Android SDK (Android Studio) dan Java 17.
3. Salin dari backup:
   - `key.properties` → `android/key.properties`
   - `my-release-key.jks` → `android/app/keystore/my-release-key.jks`

Setiap rilis:

```bash
tools/release/build_aab.sh
```

Lalu upload `build/app/outputs/bundle/release/app-release.aab` di Play Console
→ *Uji dan rilis → Produksi → Buat rilis baru*.

## Cara B: GitHub Actions (tanpa perlu laptop yang sudah disiapkan)

### Sekali saja: isi secrets

Dari laptop yang sudah punya `android/key.properties` + keystore:

```bash
brew install gh && gh auth login
tools/release/setup_github_secrets.sh
```

Ini mengisi `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS` di repo GitHub.

### Opsional: upload otomatis ke Play

Tanpa langkah ini workflow hanya membuat AAB (unduh dari halaman run →
*Artifacts*). Supaya langsung terkirim ke Play sebagai **draf**:

1. [Google Cloud Console](https://console.cloud.google.com) → buat/pilih
   project → aktifkan **Google Play Android Developer API**.
2. *IAM & Admin → Service accounts* → buat service account → tab *Keys* →
   *Add key → JSON*. Simpan file JSON-nya (jangan di folder project).
3. Play Console → *Pengguna dan izin* → *Undang pengguna baru* → isi email
   service account → beri akses ke Muslimku dengan izin rilis
   (*Rilis ke produksi…* dan *Rilis aplikasi ke jalur pengujian*).
4. Simpan JSON-nya sebagai secret:

   ```bash
   tools/release/setup_github_secrets.sh ~/Downloads/nama-file-service-account.json
   ```

### Setiap rilis

1. Commit & push kenaikan versi ke `main`.
2. GitHub → *Actions* → **Release (Play Store)** → *Run workflow* → pilih track.
3. Kalau upload otomatis aktif: buka Play Console → rilis draf → periksa →
   *Kirim untuk ditinjau*. Kalau tidak: unduh AAB dari *Artifacts* dan upload
   manual.

## Pemberitahuan update di aplikasi

Sejak 1.5.1 aplikasi menanyakan Google Play saat dibuka. Kalau ada versi
lebih baru, pengguna melihat lembar "Pembaruan tersedia", mengunduh di latar
belakang, lalu menekan **Pasang** (`lib/features/app_update/application/app_update_provider.dart`).

- Hanya terlihat oleh pengguna yang **sudah memasang versi berisi fitur ini**
  dari Play. Rilis pertama yang memicunya adalah rilis setelah 1.5.1.
- "Nanti saja" menyembunyikan versi itu 3 hari. Untuk update penting, set
  *in-app update priority* 4–5 lewat Play Developer API: jedanya jadi 1 hari.
- Tidak bisa dicoba di debug build. Uji lewat *Pengujian internal* atau
  *Internal app sharing*: pasang versi lama dari Play, upload versi lebih baru,
  lalu buka aplikasinya.
- Lihat tampilannya tanpa Play:
  `fvm flutter run --dart-define=MUSLIMKU_DEMO_UPDATE=true`.

## Aset listing toko

`assets_src/store/` berisi icon 512, grafis fitur 1024×500 dan 8 screenshot
1080×1920 untuk *Listingan toko utama*. Sumber icon dan logo ada di
`assets_src/brand/`; setelah mengganti icon, jalankan
`fvm dart run flutter_launcher_icons`.

## Kalau gagal

| Pesan | Artinya |
|---|---|
| `android/key.properties not found` | File signing belum disalin ke laptop ini (lihat Cara A). |
| `signed with SHA-1 …, but Play expects …` | Keystore yang dipakai salah. |
| Play: *Version code … has already been used* | Naikkan angka `+N` di `pubspec.yaml`. |
| Play: *signed with the wrong key* | Cek SHA-1 di Play Console → Penandatanganan aplikasi → Upload kunci. |
