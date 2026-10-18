# Nada Music

Aplikasi musik **Android dengan Flutter**: cari musik dari YouTube, putar lagu,
unduh audio untuk offline, dan buat playlist pribadi. Bahasa antarmuka: Indonesia.
Desain dan implementasi baru; Harmony Music dipelajari sebagai referensi fitur.

## Fitur

- Pencarian judul/artis dan tautan video YouTube/YouTube Music.
- Pemutar, seek, antrean, next/previous, shuffle, repeat satu/semua lagu.
- Layanan audio Android dengan kontrol notifikasi dan audio focus.
- Unduhan berurutan dengan progres, pembatalan, retry, dan deteksi berkas tidak lengkap.
- Pemutaran berkas lokal lebih dahulu bila lagu telah diunduh.
- Playlist: buat, ubah nama, hapus, tambah/hapus lagu, putar semua, unduh semua.
- Penyimpanan JSON dengan penulisan atomik dan cadangan terakhir.

Unduhan berada di **ruang penyimpanan aplikasi**. Menghapus playlist tidak menghapus
unduhan. Menghapus data/uninstall aplikasi akan menghapus keduanya. Antrean unduhan
tidak dipulihkan setelah proses dimatikan; berkas yang belum selesai dibersihkan
pada peluncuran berikutnya. Versi awal ini belum menyediakan ekspor berkas,
sinkronisasi akun, atau layanan unduhan latar belakang tersendiri.

Integrasi YouTube menggunakan `youtube_explode_dart` dan **bukan API resmi**.
Hasil pencarian berasal dari YouTube, tanpa personalisasi katalog YouTube Music.
Perubahan layanan, pembatasan wilayah, atau pembatasan akses dapat menyebabkan
lagu tertentu tidak tersedia. Unduh konten sesuai izin pemiliknya.

## Menjalankan

Prasyarat: Flutter **3.38.5** (Dart 3.10.4), JDK 17, Android SDK API 36,
build-tools 36.0.0, NDK 28.2.13676358. Modul dependensi juga memakai SDK/build-tools 35.
Perangkat minimal Android 7/API 24.

Di cloud `/workspace`, setup toolchain dan dependensi:

```bash
cd /workspace/proyek-pegajaran
bash tool/setup.sh
source tool/env.sh
```

Script menggunakan direktori `/workspace/tools` untuk toolchain dan
`/workspace/.cache/nada` untuk cache; tidak mengubah `HOME`. Checksum Android SDK,
JDK, dan Gradle diverifikasi. Java memakai proxy cloud melalui konfigurasi
Gradle di cache, tanpa menyalin kredensial. Jalankan setup ulang setelah perubahan
proxy. `tool/env.sh` khusus lingkungan cloud; pada komputer sendiri gunakan
toolchain Flutter/Android yang telah dipasang.

```bash
flutter pub get --enforce-lockfile
flutter devices
flutter run -d <id-perangkat-android>
```

Build APK pengembangan:

```bash
flutter build apk --debug
```

Hasil: `build/app/outputs/flutter-apk/app-debug.apk`. Instal dengan
`adb install -r build/app/outputs/flutter-apk/app-debug.apk` jika perangkat tersedia.
Build release masih memakai debug signing untuk pengembangan; konfigurasi kunci
rilis sendiri diperlukan sebelum distribusi produksi.

## Pemeriksaan

```bash
bash tool/check.sh
# Terpisah: pemeriksaan jaringan sungguhan, memerlukan akses YouTube.
dart run tool/youtube_smoke.dart
```

Pengujian otomatis memakai audio/katalog fixture dan menguji data di filesystem
sementara. Mereka memeriksa persistensi playlist, pemulihan cadangan, antrean dan
pembatalan unduhan, retry, pemilihan audio offline, navigasi pemutar, akhir antrean,
repeat, navigasi antarmuka, dan validasi dialog playlist. Mereka tidak membuktikan
bahwa ekstraksi YouTube atau decoding audio di perangkat Android bekerja.

Smoke test jaringan melakukan pencarian, mengambil manifest audio, lalu membaca
sebagian respons audio. Tes ini tidak masuk pengujian unit/CI agar pembatasan
layanan eksternal tidak menyamarkan regresi aplikasi. Workflow GitHub Actions
menjalankan analisis, pengujian, dan build APK debug pada push/PR.

Untuk pemeriksaan perangkat: cari lagu, putar/jeda/seek, gunakan next dan repeat,
uji notifikasi saat layar mati, unduh lagu, aktifkan mode pesawat, putar dari
Unduhan, lalu tutup/buka aplikasi dan pastikan playlist serta audio tetap tersedia.

## Struktur

| Lokasi | Tanggung jawab |
| --- | --- |
| `lib/services/music_catalog.dart` | Pencarian dan resolusi stream YouTube |
| `lib/services/music_player.dart` | Audio handler, antrean, audio focus |
| `lib/services/download_manager.dart` | Antrean dan penyimpanan audio |
| `lib/services/library_store.dart` | Persistensi playlist dan metadata unduhan |
| `lib/ui/app.dart` | Jelajahi, Unduhan, Playlist, pemutar |
| `test/` | Pengujian dengan filesystem sementara dan fixture audio |

Kebutuhan jaringan cloud: GitHub serta registry paket, `storage.googleapis.com`
(Flutter), repositori Google/Maven/Gradle (Android), `www.youtube.com`,
`youtube.com`, `music.youtube.com`, `img.youtube.com`, `i.ytimg.com`, dan
`*.googlevideo.com`. Aplikasi ini tidak memerlukan API key atau login.
