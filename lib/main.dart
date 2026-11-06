import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(const AbsensiApp());

// ---------------------------------------------------------------------------
// PENGATURAN LOKASI KANTOR  (GANTI sesuai lokasi kantor yang sebenarnya)
// Cara mengambil koordinat: buka Google Maps, tekan lama di titik kantor,
// lalu salin angka koordinat yang muncul (contoh: -7.6298, 111.5239).
// ---------------------------------------------------------------------------
const double kKantorLat = -7.6298;
const double kKantorLng = 111.5239;
const double kRadiusMeter = 200; // batas jarak absen dari kantor (meter)

// Ubah menjadi false jika ingin menguji aplikasi di luar area kantor.
const bool kCekLokasi = false;

// ---------------------------------------------------------------------------
// Helper format tanggal & jam (tanpa paket tambahan)
// ---------------------------------------------------------------------------
const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _bulan = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

String tanggalLengkap(DateTime d) =>
    '${_hari[d.weekday - 1]}, ${d.day} ${_bulan[d.month - 1]} ${d.year}';

String _dua(int n) => n.toString().padLeft(2, '0');
String jam(DateTime d) => '${_dua(d.hour)}:${_dua(d.minute)}';
String jamDetik(DateTime d) => '${jam(d)}:${_dua(d.second)}';

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ---------------------------------------------------------------------------
// Model data
// ---------------------------------------------------------------------------
/// Data akun karyawan.
class Karyawan {
  const Karyawan({
    required this.id,
    required this.password,
    required this.nama,
    required this.jabatan,
  });

  final String id;
  final String password;
  final String nama;
  final String jabatan;
}

// ---------------------------------------------------------------------------
// DAFTAR AKUN  (tambah atau ubah akun di sini)
// ---------------------------------------------------------------------------
const daftarKaryawan = <Karyawan>[
  Karyawan(id: 'FIF001', password: '123456', nama: 'Budi Santoso', jabatan: 'Staf'),
  Karyawan(id: 'FIF002', password: '123456', nama: 'Siti Rahma', jabatan: 'Supervisor'),
  Karyawan(id: 'FIF003', password: '123456', nama: 'Andi Pratama', jabatan: 'Admin'),
];

class AbsenGagal implements Exception {
  AbsenGagal(this.pesan);
  final String pesan;
}

/// Bukti satu kali absen: waktu, lokasi, jarak ke kantor, dan foto selfie.
class Bukti {
  Bukti({
    required this.waktu,
    required this.lat,
    required this.lng,
    required this.jarak,
    required this.fotoPath,
  });

  final DateTime waktu;
  final double lat;
  final double lng;
  final double jarak; // meter dari kantor
  final String fotoPath;
}

class Absensi {
  Absensi({required this.masuk, required this.terlambat});

  final Bukti masuk;
  final bool terlambat;
  Bukti? pulang;

  String get status => terlambat ? 'Terlambat' : 'Hadir';
}

// ---------------------------------------------------------------------------
// Aplikasi
// ---------------------------------------------------------------------------
class AbsensiApp extends StatelessWidget {
  const AbsensiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Absensi FIF Group',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

// ---------------------------------------------------------------------------
// Halaman Login
// ---------------------------------------------------------------------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _sembunyi = true;
  String? _error;

  @override
  void dispose() {
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _masuk() {
    if (!_formKey.currentState!.validate()) return;
    final id = _idCtrl.text.trim().toUpperCase();
    final user = daftarKaryawan
        .where((k) => k.id == id && k.password == _passCtrl.text)
        .firstOrNull;
    if (user != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeShell(karyawan: user)),
      );
    } else {
      setState(() => _error = 'ID karyawan atau password salah');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.badge_outlined,
                        size: 72, color: tema.colorScheme.primary),
                    const SizedBox(height: 12),
                    Text(
                      'Absensi FIF Group',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Masuk untuk mencatat kehadiran',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _idCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'ID Karyawan',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'ID karyawan wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _sembunyi,
                      onFieldSubmitted: (_) => _masuk(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_sembunyi
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _sembunyi = !_sembunyi),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Password wajib diisi'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: tema.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _masuk,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Masuk'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Akun demo: FIF001, FIF002, FIF003 (password 123456)',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kerangka utama (navigasi bawah + data sementara di memori)
// ---------------------------------------------------------------------------
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.karyawan});

  final Karyawan karyawan;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  DateTime _now = DateTime.now();
  Timer? _timer;
  bool _sibuk = false; // true saat memeriksa lokasi / membuka kamera
  final List<Absensi> _riwayat = []; // terbaru di indeks 0

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Absensi? get _hariIni =>
      (_riwayat.isNotEmpty && sameDay(_riwayat.first.masuk.waktu, _now))
          ? _riwayat.first
          : null;

  void _pesan(String teks) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(teks)));
  }

  /// Memeriksa GPS, mengecek jarak ke kantor, lalu mengambil foto selfie.
  Future<Bukti> _ambilBukti() async {
    final aktif = await Geolocator.isLocationServiceEnabled();
    if (!aktif) {
      throw AbsenGagal('GPS belum aktif. Nyalakan lokasi di HP lalu coba lagi.');
    }

    var izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) {
      izin = await Geolocator.requestPermission();
    }
    if (izin == LocationPermission.denied) {
      throw AbsenGagal('Izin lokasi ditolak. Absen membutuhkan izin lokasi.');
    }
    if (izin == LocationPermission.deniedForever) {
      throw AbsenGagal(
        'Izin lokasi ditolak permanen. Aktifkan lewat Pengaturan > Aplikasi > '
        'Absensi FIF Group > Izin.',
      );
    }

    final Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } on TimeoutException {
      throw AbsenGagal('Gagal mendapatkan lokasi. Coba lagi di tempat terbuka.');
    }

    if (pos.isMocked) {
      throw AbsenGagal('Lokasi palsu (mock location) terdeteksi.');
    }

    final jarak = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      kKantorLat,
      kKantorLng,
    );
    if (kCekLokasi && jarak > kRadiusMeter) {
      throw AbsenGagal(
        'Kamu di luar area kantor (${jarak.round()} m dari kantor, '
        'batas ${kRadiusMeter.round()} m).',
      );
    }

    final foto = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (foto == null) {
      throw AbsenGagal('Foto selfie dibatalkan. Absen belum tercatat.');
    }

    return Bukti(
      waktu: DateTime.now(),
      lat: pos.latitude,
      lng: pos.longitude,
      jarak: jarak,
      fotoPath: foto.path,
    );
  }

  Future<void> _prosesAbsen({required bool masuk}) async {
    if (_sibuk) return;
    if (masuk && _hariIni != null) return;
    if (!masuk && (_hariIni == null || _hariIni!.pulang != null)) return;

    setState(() => _sibuk = true);
    try {
      final bukti = await _ambilBukti();
      if (!mounted) return;

      if (masuk) {
        final t = bukti.waktu;
        // Batas jam masuk 08:00, lewat dari itu dianggap terlambat
        final terlambat = t.hour > 8 || (t.hour == 8 && t.minute > 0);
        setState(() {
          _riwayat.insert(0, Absensi(masuk: bukti, terlambat: terlambat));
        });
        _pesan('Absen masuk tercatat pukul ${jam(t)}');
      } else {
        setState(() => _hariIni!.pulang = bukti);
        _pesan('Absen pulang tercatat pukul ${jam(bukti.waktu)}');
      }
    } on AbsenGagal catch (e) {
      if (mounted) _pesan(e.pesan);
    } catch (e) {
      if (mounted) _pesan('Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  void _keluar() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final halaman = <Widget>[
      BerandaTab(
        now: _now,
        hariIni: _hariIni,
        sibuk: _sibuk,
        onMasuk: () => _prosesAbsen(masuk: true),
        onPulang: () => _prosesAbsen(masuk: false),
      ),
      RiwayatTab(riwayat: _riwayat),
      ProfilTab(karyawan: widget.karyawan, onKeluar: _keluar),
    ];
    const judul = ['Beranda', 'Riwayat Absensi', 'Profil'];

    return Scaffold(
      appBar: AppBar(title: Text(judul[_index])),
      body: halaman[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Riwayat'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab Beranda
// ---------------------------------------------------------------------------
class BerandaTab extends StatelessWidget {
  const BerandaTab({
    super.key,
    required this.now,
    required this.hariIni,
    required this.sibuk,
    required this.onMasuk,
    required this.onPulang,
  });

  final DateTime now;
  final Absensi? hariIni;
  final bool sibuk;
  final VoidCallback onMasuk;
  final VoidCallback onPulang;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final sudahMasuk = hariIni != null;
    final sudahPulang = hariIni?.pulang != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: tema.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            child: Column(
              children: [
                Text(
                  jamDetik(now),
                  style: tema.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: tema.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tanggalLengkap(now),
                  style: tema.textTheme.titleMedium?.copyWith(
                    color: tema.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status hari ini', style: tema.textTheme.titleMedium),
                const SizedBox(height: 12),
                _baris('Jam masuk', sudahMasuk ? jam(hariIni!.masuk.waktu) : '-'),
                _baris('Jam pulang',
                    sudahPulang ? jam(hariIni!.pulang!.waktu) : '-'),
                _baris('Keterangan',
                    sudahMasuk ? hariIni!.status : 'Belum absen'),
                const SizedBox(height: 4),
                Text(
                  'Jam kerja 08:00 - 17:00. Masuk setelah 08:00 dihitung terlambat.',
                  style: tema.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  kCekLokasi
                      ? 'Absen hanya bisa dilakukan dalam radius '
                          '${kRadiusMeter.round()} m dari kantor, dengan foto selfie.'
                      : 'Pengecekan area kantor sedang dimatikan (mode uji).',
                  style: tema.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (sibuk) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(
            'Memeriksa lokasi dan menyiapkan kamera...',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: (sudahMasuk || sibuk) ? null : onMasuk,
          icon: const Icon(Icons.login),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Absen Masuk'),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: (sudahMasuk && !sudahPulang && !sibuk) ? onPulang : null,
          icon: const Icon(Icons.logout),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Absen Pulang'),
          ),
        ),
      ],
    );
  }

  Widget _baris(String label, String nilai) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(nilai, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab Riwayat
// ---------------------------------------------------------------------------
class RiwayatTab extends StatelessWidget {
  const RiwayatTab({super.key, required this.riwayat});

  final List<Absensi> riwayat;

  @override
  Widget build(BuildContext context) {
    if (riwayat.isEmpty) {
      return const Center(child: Text('Belum ada data absensi'));
    }
    final tema = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: riwayat.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final r = riwayat[i];
        final warna =
            r.terlambat ? tema.colorScheme.error : tema.colorScheme.primary;
        return Card(
          child: ListTile(
            onTap: () => _tampilDetail(context, r),
            leading: CircleAvatar(
              backgroundImage: FileImage(File(r.masuk.fotoPath)),
            ),
            title: Text(tanggalLengkap(r.masuk.waktu)),
            subtitle: Text(
              'Masuk ${jam(r.masuk.waktu)}  •  '
              'Pulang ${r.pulang != null ? jam(r.pulang!.waktu) : '-'}',
            ),
            trailing: Text(
              r.status,
              style: TextStyle(color: warna, fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }

  void _tampilDetail(BuildContext context, Absensi r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tanggalLengkap(r.masuk.waktu),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              _BuktiItem(judul: 'Absen Masuk', bukti: r.masuk),
              if (r.pulang != null) ...[
                const SizedBox(height: 16),
                _BuktiItem(judul: 'Absen Pulang', bukti: r.pulang!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BuktiItem extends StatelessWidget {
  const _BuktiItem({required this.judul, required this.bukti});

  final String judul;
  final Bukti bukti;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(bukti.fotoPath),
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const SizedBox(
              width: 96,
              height: 96,
              child: Icon(Icons.broken_image),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(judul,
                  style: tema.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text('Pukul ${jam(bukti.waktu)}'),
              Text(
                'Lokasi: ${bukti.lat.toStringAsFixed(5)}, '
                '${bukti.lng.toStringAsFixed(5)}',
              ),
              Text('Jarak dari kantor: ${bukti.jarak.round()} m'),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab Profil
// ---------------------------------------------------------------------------
class ProfilTab extends StatelessWidget {
  const ProfilTab({super.key, required this.karyawan, required this.onKeluar});

  final Karyawan karyawan;
  final VoidCallback onKeluar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),
        CircleAvatar(
          radius: 44,
          backgroundColor: tema.colorScheme.primaryContainer,
          child: Icon(Icons.person,
              size: 48, color: tema.colorScheme.onPrimaryContainer),
        ),
        const SizedBox(height: 12),
        Text(
          karyawan.nama,
          textAlign: TextAlign.center,
          style: tema.textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('ID Karyawan'),
                subtitle: Text(karyawan.id),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.work_outline),
                title: const Text('Jabatan'),
                subtitle: Text(karyawan.jabatan),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.business_outlined),
                title: Text('Perusahaan'),
                subtitle: Text('FIF Group'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onKeluar,
          icon: const Icon(Icons.exit_to_app),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Keluar'),
          ),
        ),
      ],
    );
  }
}
