# Absensi FIF Group

Aplikasi absensi karyawan untuk Android, dibuat dengan Flutter sebagai tugas mata kuliah Pemrograman Bergerak.

## Fitur
- Login banyak akun (karyawan)
- Absen masuk dan absen pulang
- Pencatatan lokasi (GPS) saat absen
- Foto selfie saat absen
- Status kehadiran: Hadir atau Terlambat (batas masuk 08:00)
- Riwayat absensi beserta foto, koordinat, dan jarak dari kantor
- Halaman profil karyawan

## Akun demo
| ID | Password | Peran |
|----|----------|-------|
| FIF001 | 123456 | Karyawan |
| FIF002 | 123456 | Supervisor |
| FIF003 | 123456 | Admin |

## Cara menjalankan
1. Pasang [Flutter](https://docs.flutter.dev/get-started/install) dan Android SDK.
2. Unduh atau clone repositori ini.
3. Di folder proyek, jalankan:
   ```
   flutter pub get
   flutter run
   ```
4. Sambungkan HP Android dengan USB debugging aktif, atau gunakan emulator.

## Teknologi
- Flutter (Dart)
- geolocator (GPS)
- image_picker (kamera)
