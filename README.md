# Dashcam Detect

Aplikasi dashcam pintar dengan deteksi objek real-time menggunakan Flutter dan model YOLO/TFLite. Aplikasi ini mendeteksi kendaraan dan pejalan kaki di depan kendaraan, memberikan peringatan visual serta suara beep saat objek terlalu dekat, serta mencatat riwayat peringatan.

![Flutter](https://img.shields.io/badge/Flutter-3.14+-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.14+-blue?logo=dart)
![Platform](https://img.shields.io/badge/Platform-Android%20|%20iOS%20|%20Windows%20|%20macOS-green)
![License](https://img.shields.io/badge/License-MIT-green)

## 📱 Tentang Aplikasi

Dashcam Detect adalah aplikasi pendeteksi objek di jalan raya yang menggunakan kamera ponsel sebagai input dan model machine learning YOLO (via TensorFlow Lite) untuk mengidentifikasi objek di sekitar. Aplikasi cocok digunakan sebagai bantuan pengemudi untuk meningkatkan kesadaran terhadap objek di depan kendaraan.

## ✨ Fitur Utama

- **Deteksi objek real-time** menggunakan kamera dan model YOLO/TFLite (`best.tflite`)
- **Deteksi berbagai kelas objek**: mobil, truk, bus, motor, pejalan kaki, pengendara, sepeda
- **Peringatan visual tiga level**: AMAN (hijau), WASPADA (oranye), BAHAYA (merah)
- **Estimasi jarak objek** ke depan kendaraan
- **Suara beep peringatan** saat objek masuk zona bahaya (dapat diaktifkan/dimatikan)
- **Riwayat peringatan** dengan timestamp, nama objek, dan jarak (maksimal 100 entri)
- **Pengaturan kalibrasi kamera**: jarak bahaya, jarak waspada, lebar jalur tengah, kepercayaan deteksi, sudut pandang kamera (HFOV)
- **Mode portrait dan landscape** sesuai orientasi layar
- **Wakelock**: layar tetap nyala saat aplikasi digunakan
- **Simpan pengaturan** secara lokal menggunakan SharedPreferences

## 🛠️ Teknologi yang Digunakan

| Teknologi | Versi | Keterangan |
|-----------|-------|------------|
| Flutter | ^3.14.0 | Framework UI |
| Dart | ^3.14.0 | Bahasa pemrograman |
| ultralytics_yolo | ^0.7.2 | Deteksi objek YOLO/TFLite |
| audioplayers | ^6.8.1 | Pemutaran suara beep |
| shared_preferences | ^2.5.6 | Penyimpanan lokal pengaturan & riwayat |
| permission_handler | ^13.0.2 | Manajemen izin kamera |
| wakelock_plus | ^1.8.2 | Mencegah layar mati |
| material_ui | ^1.1.0 | Komponen UI tambahan |

## 📋 Persyaratan Sistem

- Flutter SDK 3.14.0 atau lebih baru
- Dart SDK 3.14.0 atau lebih baru
- Android: Android 6.0 (API 23) atau lebih baru dengan kamera
- iOS: iOS 12.0 atau lebih baru
- Izin kamera harus diberikan saat pertama kali menjalankan aplikasi

## 🚀 Cara Instalasi

### 1. Clone repositori

```bash
git clone https://github.com/Damarilham/dashcam_app.git
cd dashcam_app
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Jalankan aplikasi

```bash
flutter run
```

Pastikan perangkat Anda terhubung dan mode debugging USB diaktifkan (untuk Android).

## 📦 Struktur Aset

Pastikan file-file berikut ada di direktori proyek:

```
assets/
  beep.wav              # Suara peringatan beep
  models/
    best.tflite         # Model YOLO deteksi objek
```

File aset sudah dikonfigurasi di `pubspec.yaml`. Jika model TFLite tidak ditemukan, aplikasi akan menampilkan pesan error saat inisialisasi kamera.

## ⚙️ Pengaturan & Kalibrasi

Buka layar **Pengaturan** melalui tombol gear di layar utama untuk menyesuaikan:

| Pengaturan | Default | Keterangan |
|------------|---------|------------|
| Suara beep | Aktif | Nyala/matikan suara peringatan |
| Sertakan pejalan kaki & pesepeda | Nonaktif | Sertakan objek non-kendaraan dalam deteksi |
| Jarak bahaya (beep) | 10 m | Jarak minimum sebelum beep berdenting |
| Jarak waspada | 25 m | Ambang batas status WASPADA |
| Lebar jalur tengah | 20% layar | Area tengah yang dipantau deteksi |
| Kepercayaan minimum | 40% | Ambang confidence model YOLO |
| Sudut pandang kamera | 70° | HFOV kamera untuk estimasi jarak |

### Tips Kalibrasi HFOV

Arahkan kamera ke objek yang jaraknya Anda tahu, lalu ubah nilai **Sudut pandang kamera** sampai angka meter yang ditampilkan layar cocok dengan jarak nyata. Semakin kecil sudut, semakin jauh jarak yang terbaca.


## 📸 Cara Penggunaan

1. Berikan izin kamera saat diminta saat pertama kali membuka aplikasi
2. Tempatkan ponsel di depan kaca depan kendaraan dengan pemandangan jalan yang jelas
3. Aplikasi akan secara otomatis mendeteksi objek di jalur tengah
4. Peringatan akan ditampilkan di atas layar dengan warna sesuai tingkat bahaya
5. Suara beep akan berbunyi jika objek masuk zona bahaya (jika diaktifkan)
6. Lihat riwayat peringatan melalui tombol jam sejajar
7. Atur pengaturan melalui tombol gear

## 🏗️ Struktur Proyek

```
dashcam_app/
├── lib/
│   ├── main.dart       # Titik masuk aplikasi dan layar utama
│   ├── core.dart       # Logic deteksi, pengaturan, riwayat, dan engine
│   └── screens.dart    # Layar pengaturan dan riwayat
├── assets/
│   ├── beep.wav
│   └── models/
│       └── best.tflite
├── android/            # Project Android native
├── ios/                # Project iOS native
├── macos/              # Project macOS native
├── windows/            # Project Windows native
├── web/                # Build web
├── pubspec.yaml        # Konfigurasi dependencies Flutter
└── README.md
```

## ⚠️ Peringatan Penggunaan

Aplikasi ini adalah **bantuan pengemudi**, bukan sistem pengemudi otonom. Selalu waspada dan patuhi peraturan lalu lintas. Pengembang tidak bertanggung jawab atas kecelakaan atau kerugian yang timbul dari penggunaan aplikasi ini.

## 🤝 Kontribusi

Kontribusi sangat diterima! Silakan:

1. Fork repositori ini
2. Buat branch fitur baru (`git checkout -b fitur-baru`)
3. Commit perubahan Anda (`git commit -m 'Menambahkan fitur baru'`)
4. Push ke branch (`git push origin fitur-baru`)
5. Buat Pull Request

## 📄 Lisensi

Proyek ini dilisensikan di bawah [MIT License](LICENSE).

## 📞 Kontak

Jika ada pertanyaan atau saran, silakan buka [Issue](https://github.com/Damarilham/dashcam_app/issues) pada repositori ini.

---

Dibuat dengan ❤️ menggunakan Flutter