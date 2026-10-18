# Hasil pemeriksaan versi awal

- Flutter 3.38.5 / Dart 3.10.4, Temurin JDK 17, Android SDK 35/36,
  NDK 28.2.13676358, dan CMake 3.22.1 dipasang di cloud.
- `flutter analyze`: bersih.
- `flutter test`: **23 pengujian lulus**. Penyimpanan/unduhan memakai filesystem
  nyata sementara; katalog dan decoder native menggunakan fixture.
- `flutter build apk --debug`: berhasil.
- `apksigner verify`: tanda tangan APK valid (kunci debug).
- Metadata APK: `id.nada.music`, versi `0.1.0+1`, minimum API 24, target API 36,
  ABI ARMv7/ARM64/x86_64.
- Beranda dirender pada ukuran 412×892 dan diperiksa secara visual.
  Tangkapan: `build/screenshots/nada-home.png`.

## Belum terverifikasi

- `dart run tool/youtube_smoke.dart` gagal: koneksi YouTube melalui proxy cloud
  ditolak. Permintaan HTTPS langsung ke `www.youtube.com` dan `img.youtube.com`
  mendapat `403 Forbidden`. Ini belum membuktikan ekstraktor dapat bekerja pada
  jaringan/perangkat pengguna; pencarian dan streaming langsung masih perlu diuji.
- Belum ada pengujian pada perangkat Android nyata. Decoding audio, kontrol
  notifikasi, interupsi telepon, dan pemutaran dengan layar mati masih memerlukan
  uji perangkat.
- `flutter doctor` juga melaporkan target desktop/browser yang tidak dipersiapkan
  dan ADB yang mencoba menulis ke home cloud yang hanya dapat dibaca. Itu bukan
  pemeriksaan wajib workflow build/test Android ini. Jalankan APK pada perangkat
  sendiri untuk uji native; gunakan `tool/check.sh` untuk pemeriksaan cloud.

Draf domain jaringan telah disimpan untuk ditinjau di pengaturan lingkungan.
Menyimpan draf tidak membuktikan akses jaringan runtime sudah berubah. Setelah
pengaturan diterapkan, ulangi smoke test YouTube sebelum menyatakan integrasi
streaming siap. Publikasi konfigurasi lingkungan dilakukan melalui pengaturan lingkungan.
