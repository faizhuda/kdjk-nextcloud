<div align="center">
  <img src="https://upload.wikimedia.org/wikipedia/commons/6/60/Nextcloud_Logo.svg" alt="Nextcloud Logo" width="120"/>

# Nextcloud: Sistem Kolaborasi dan Penyimpanan Data Self-Hosted

*Implementasi Self-Hosted Cloud Storage dan Sistem Kolaborasi Berbasis Docker*

</div>

<a id="toc"></a>

## Daftar Isi

| [Sekilas Tentang](#abstrak) | [Instalasi](#instalasi--konfigurasi) | [Konfigurasi](#7-konfigurasi-reverse-proxy-via-web-gui) | [Keamanan](#keamanan) | [Cara Pemakaian](#penggunaan-nextcloud) | [Pembahasan](#pembahasan) | [Referensi](#referensi) |

## Perubahan Terbaru

Bagian ini mencatat perubahan-perubahan yang telah dilakukan pada repository untuk merapikan konfigurasi dan mengikuti praktik terbaik:

- **`.gitignore`**: Diperbarui untuk mengabaikan file runtime dan rahasia seperti `config.php`, data, dan `.env`.
- **`.env.example`**: Ditambahkan contoh variabel lingkungan yang diperlukan (database, path volume, dsb.).
- **`docker-compose.yml`**: Dirombak agar menggunakan variabel lingkungan (`${...}`), men-pin image versi, dan menambahkan healthchecks untuk `db` dan `app`.
- **`docker-compose.ci.yml`**: Ditambahkan sebagai override khusus CI agar tidak mem-mount `config.php` dari repo saat tes otomatis.
- **`scripts/backup.sh` dan `scripts/restore.sh`**: Ditambahkan skrip bantuan untuk backup/restore database dan data Nextcloud.
- **`config.php.example`**: Ditambahkan contoh `config.php` aman (tanpa rahasia dan dengan `installed => false`).
- **`config.php`**: File runtime `config.php` dihapus dari version control untuk mencegah bocornya rahasia dan memudahkan instalasi awal di CI/lokal.
- **Workflow CI `smoke.yml`**: Workflow smoke test yang sebelumnya ditambahkan telah dinonaktifkan/dihapus atas permintaan pengguna (terlalu rumit untuk alur saat ini).

Catatan singkat:
- Jika ingin menjalankan CI smoke test lagi nanti, ada file `docker-compose.ci.yml` dan langkah-langkah yang sempat dibuat; bisa diaktifkan kembali atau disederhanakan.
- Jangan commit berkas sensitif (`.env`, `config.php`) — gunakan `config.php.example` sebagai referensi.

## Abstrak

[⬆️ Kembali ke atas](#daftar-isi)

Dokumen ini menjelaskan implementasi Nextcloud sebagai sistem kolaborasi dan penyimpanan data self-hosted. Implementasi dilakukan pada lingkungan Mini-PC berbasis Ubuntu 22.04 dengan penggunaan Docker, Docker Compose, Nginx Proxy Manager, dan MariaDB. Tujuan pekerjaan ini adalah menyediakan panduan teknis lengkap yang mencakup instalasi, konfigurasi, keamanan, backup, serta pengujian performa awal.

---

## Latar Belakang dan Tujuan

[⬆️ Kembali ke atas](#daftar-isi)

Kebutuhan organisasi/akademik terhadap sistem penyimpanan dan kolaborasi data yang aman, dapat dikendalikan, dan hemat biaya mendorong penggunaan solusi self-hosted. Nextcloud dipilih karena fitur kolaborasi (file sharing, calendar, talk, docs), fleksibilitas deployment, dan dukungan ekosistem aplikasi. Tujuan laporan ini adalah:

* Mendesain dan mengimplementasikan Nextcloud self-hosted pada Mini-PC.
* Menyusun dokumentasi teknis yang dapat direplikasi.
* Melakukan pengujian performa dasar dan menyiapkan prosedur backup dan hardening.

---

## Instalasi & Konfigurasi

[⬆️ Kembali ke atas](#daftar-isi)

### 1. Persiapan Host

1. Update sistem:

```bash
sudo apt update && sudo apt upgrade -y
```

Perintah di atas memperbarui daftar paket dan meng-upgrade seluruh paket agar sistem dalam kondisi terbaru.

2. Pasang Docker & Docker Compose (ikuti panduan resmi Docker untuk Ubuntu 22.04).
3. Pastikan port 80 terbuka untuk Nginx Proxy Manager/Let's Encrypt agar dapat menerbitkan sertifikat SSL.

---

### 2. Struktur Direktori

Sebelum menjalankan Nextcloud, buat struktur direktori untuk menampung data dan file konfigurasi.

```bash
mkdir data-nc docker
```

Membuat dua folder utama:

* `data-nc` → untuk data Nextcloud (database dan file Nextcloud)
* `docker` → untuk file konfigurasi Docker (misalnya `docker-compose.yml`)

Lalu masuk ke direktori `data-nc` dan buat subfolder:

```bash
cd data-nc
mkdir db nc
```

Folder `db` akan berisi data MariaDB, sedangkan `nc` akan menyimpan file aplikasi Nextcloud yang di-mount dari container.

Kembali ke direktori sebelumnya:

```bash
cd -
```

Masuk ke folder konfigurasi Docker:

```bash
cd docker
```

---

### 3. Menjalankan Docker Compose Pertama Kali

Setelah file `docker-compose.yml` disiapkan, jalankan container untuk pertama kali:

```bash
docker-compose up -d
```

> ⚠️ **Catatan penting:**
> Sebelum menjalankan perintah ini, **pastikan baris berikut di file `docker-compose.yml` dijadikan komentar**:
>
> ```yaml
> # - ./config.php:/var/www/html/config/config.php
> ```
>
> Baris ini memetakan file konfigurasi `config.php` dari host ke dalam container. Jika belum dibuat, container akan error saat dijalankan pertama kali.

Setelah container berjalan, lakukan instalasi awal Nextcloud melalui browser (membuat akun admin, memilih database, dll).

---


### Panduan singkat deployment aman

1. Salin `.env.example` menjadi `.env` dan isi password serta path host sebelum menjalankan:

```powershell
copy .env.example .env
# sunting .env dan masukkan password kuat serta path DB/NC yang sesuai
```

2. Jangan pernah meng-commit `.env` atau `config.php` ke repository. Repositori ini sudah menyertakan `.gitignore` untuk mencegahnya.

3. Untuk produksi, lebih disarankan menggunakan Docker Secrets atau pengelola rahasia (secret manager) daripada menyimpan rahasia dalam bentuk plaintext `.env`.

### Backup

Repositori ini menyertakan skrip bantuan backup sederhana di `./scripts/backup.sh` yang melakukan:

- Dump database MariaDB dari container `db` menggunakan `mysqldump`.
- Mengarsipkan folder `data` Nextcloud dari container `app`.

Penggunaan (dari root repo):

```powershell
./scripts/backup.sh ./backups
```

Pastikan `.env` Anda berisi `MYSQL_USER`, `MYSQL_PASSWORD`, dan `MYSQL_DATABASE` (atau ekspor variabel tersebut di shell) agar skrip dapat mengakses database.

Rekomendasi:

- Jadwalkan backup dengan cron / systemd timer, dan salin backup ke penyimpanan off-site.
- Uji prosedur restore secara berkala.


### 4. Mengambil File Konfigurasi

Setelah proses instalasi Nextcloud selesai, hentikan semua container:

```bash
docker-compose down
```

Lalu salin file konfigurasi dari container ke direktori host agar bisa disesuaikan:

```bash
cp data-nc/nc/var/www/html/config/config.php .
```

Perintah ini menyalin file `config.php` yang telah dihasilkan oleh Nextcloud ke direktori kerja (folder `docker`).

---

### 5. Mengubah Domain Terpercaya (Trusted Domains)

Sesuaikan domain publik dan URL CLI Nextcloud dengan skrip PHP berikut:

```bash
sudo php -r '$c="config.php"; $cfg = include $c; $cfg["trusted_domains"]=["mtf.idenx.id"]; $cfg["overwrite.cli.url"]="mtf.idenx.id"; file_put_contents($c, "<?php\nreturn ".var_export($cfg, true).";\n");'
```

Penjelasan:

* `trusted_domains` → Menambahkan domain publik (`mtf.idenx.id`) agar Nextcloud hanya dapat diakses dari alamat tersebut.
* `overwrite.cli.url` → Menentukan URL dasar yang digunakan Nextcloud saat diakses melalui CLI.
* Skrip ini secara otomatis membuka file `config.php`, menambahkan konfigurasi domain, dan menulis ulang hasilnya ke file yang sama.

---

### 6. Menjalankan Container Akhir

Setelah file `config.php` telah disesuaikan, aktifkan kembali baris volume pada `docker-compose.yml`:

```yaml
- ./config.php:/var/www/html/config/config.php
```

Kemudian jalankan kembali seluruh service:

```bash
docker-compose up -d
```

Sekarang semua container akan berjalan dengan konfigurasi final yang benar.
Nextcloud dapat diakses melalui domain yang telah dikonfigurasi (contoh: `http://mtf.idenx.id`).

---

### 7. Konfigurasi Reverse Proxy via Web GUI

Setelah container **Nginx Proxy Manager** dijalankan, antarmuka administrasi dapat diakses melalui browser dengan alamat:

```
http://<IP-server>:81
```

Contoh:
`http://192.168.1.10:81`

#### 1. Login Awal

Gunakan kredensial bawaan berikut:

* **Email:** `admin@example.com`
* **Password:** `changeme`

Segera ubah password setelah login pertama untuk alasan keamanan.

#### 2. Menambahkan Proxy Host

Masuk ke tab **“Proxy Hosts”** dan pilih **Add Proxy Host**, lalu isi kolom berikut:

| Kolom                     | Nilai Contoh   | Keterangan                                |
| ------------------------- | -------------- | ----------------------------------------- |
| **Domain Names**          | `mtf.idenx.id` | Domain publik untuk akses Nextcloud       |
| **Scheme**                | `http`         | Gunakan HTTP karena SSL belum diaktifkan  |
| **Forward Hostname / IP** | `IP-server`    | Nama container Nextcloud                  |
| **Forward Port**          | `23001`        | Port container Nextcloud                  |
| **Cache Assets**          | Kosong         | Untuk efisiensi akses statis              |
| **Block Common Exploits** | Centang        | Perlindungan dasar terhadap serangan umum |

#### 3. Verifikasi Akses

Buka browser dan kunjungi:

```
http://mtf.idenx.id
```

Jika konfigurasi berhasil, halaman login Nextcloud akan muncul.
Apabila domain belum resolve ke IP server, pastikan pengaturan DNS dan port forwarding router telah sesuai (port 80 diarahkan ke server host).

#### 4. Tampilan Dashboard

Antarmuka NPM berbentuk web modern yang menampilkan daftar **Proxy Host**, **SSL Certificates**, dan **Access Lists**.
Contohnya seperti berikut:

![Nginx Proxy Manager Dashboard](docs/npm-dashboard.jpg)

---

## Penggunaan Nextcloud

[⬆️ Kembali ke atas](#daftar-isi)

Setelah instalasi dan konfigurasi selesai, Nextcloud dapat diakses melalui browser di alamat domain yang sudah dikonfigurasi, misalnya:

```
http://mtf.idenx.id
```

Berikut panduan penggunaan untuk pengguna umum:

### 1. Login ke Nextcloud

* Buka browser dan akses domain Nextcloud.
![Login Nextcloud](docs/nc-login.png)
* Masukkan **username** dan **password** yang telah dibuat saat instalasi.
* Setelah login, pengguna akan masuk ke tampilan beranda (dashboard) Nextcloud.
![Dashboard Nextcloud](docs/nc-db.png)
* Klik icon berbentuk folder di pojok atas kiri bernama "Files".
![Files Nextcloud](docs/nc-files.png)

### 2. Mengunggah (Upload) File

* Klik ikon **➕ New** di atas area file.
![New Nextcloud](docs/nc-new.png)
* Pilih file dari komputer yang ingin diunggah.
* File akan tersimpan di folder utama pengguna dan dapat diakses kapan saja.
![New 2 Nextcloud](docs/nc-new2.png)

### 3. Mengunduh (Download) File

* Klik kanan pada file yang ingin diunduh, lalu pilih **Download**.
![Download Nextcloud](docs/nc-download.png)
* File akan otomatis tersimpan di perangkat lokal pengguna.

### 4. Membuat Folder Baru

* Klik ikon **➕ New** di atas area file.
![New Nextcloud](docs/nc-new.png)
* Beri nama folder sesuai kebutuhan.
![Folder Nextcloud](docs/nc-folder.png)
* Folder ini bisa diisi file pribadi atau dibagikan dengan pengguna lain.


### 5. Berbagi File atau Folder

* Klik ikon **Share (bagikan)** di samping file/folder.
* Pilih **Create public link** untuk membagikan kepada publik, atau **Internal shares** untuk membatasi akses hanya ke pengguna tertentu.
![Share Nextcloud](docs/nc-share.png)

### 6. Sinkronisasi dengan Aplikasi Desktop dan Mobile

* Unduh aplikasi Nextcloud Desktop (Windows, macOS, Linux) atau Mobile (Android, iOS) dari [https://nextcloud.com/install](https://nextcloud.com/install).
* Masukkan URL server (misal `http://mtf.idenx.id`) dan login dengan akun Nextcloud kamu.
![Folder Nextcloud](docs/nc-mobile.png)
* Aplikasi akan otomatis menyinkronkan file antara perangkat dan server.

---

## Keamanan

[⬆️ Kembali ke atas](#daftar-isi)

### Keamanan Dasar

* Aktifkan TLS (HTTPS) dengan Let's Encrypt melalui Nginx Proxy Manager.
* Selalu perbarui image Docker dan host OS.
* Konfigurasi file permission: data directory harus milik www-data pada container Nextcloud.

---

## Pembahasan

### Pendapat Tentang Aplikasi Web Ini

Nextcloud merupakan aplikasi web self-hosted yang sangat fleksibel dan mudah digunakan untuk kebutuhan kolaborasi data. Bagi pengguna umum, tampilannya mirip layanan cloud populer seperti Google Drive, tetapi dengan keunggulan utama: data sepenuhnya dikelola sendiri di server lokal. Integrasi dengan aplikasi tambahan seperti Talk, Calendar, dan OnlyOffice memberikan pengalaman kolaborasi yang lengkap tanpa bergantung pada pihak ketiga.

### Kelebihan

* **Kendali penuh atas data:** semua file tersimpan di server sendiri.
* **Open source dan gratis:** tanpa biaya lisensi.
* **Fitur kolaborasi lengkap:** sinkronisasi lintas perangkat, berbagi file, chat, dan kolaborasi dokumen.
* **Ekstensi fleksibel:** dapat menambahkan aplikasi tambahan sesuai kebutuhan.
* **Kompatibilitas luas:** berjalan di hampir semua platform (Linux, Windows, macOS, Android, iOS).

### Kekurangan

* **Butuh pengetahuan teknis awal:** instalasi dan maintenance memerlukan dasar Docker dan server.
* **Kinerja bergantung pada hardware:** pada Mini-PC atau server kecil, performa bisa menurun dengan banyak pengguna.
* **Tidak sepraktis cloud komersial:** butuh pengaturan manual untuk SSL, backup, dan DNS.

### Perbandingan dengan Aplikasi Sejenis

| Aplikasi         | Hosting              | Biaya           | Fitur Kolaborasi | Privasi Data                   | Tingkat Kustomisasi |
| ---------------- | -------------------- | --------------- | ---------------- | ------------------------------ | ------------------- |
| **Nextcloud**    | Self-hosted          | Gratis          | Lengkap          | Sangat tinggi                  | Sangat tinggi       |
| **Google Drive** | Cloud (Google)       | Freemium        | Lengkap          | Rendah (data di server Google) | Rendah              |
| **Dropbox**      | Cloud (Dropbox Inc.) | Berbayar        | Dasar            | Sedang                         | Rendah              |
| **Seafile**      | Self-hosted          | Gratis/Berbayar | Lengkap          | Tinggi                         | Tinggi              |
| **OwnCloud**     | Self-hosted          | Gratis          | Mirip Nextcloud  | Tinggi                         | Tinggi              |

Secara keseluruhan, Nextcloud lebih cocok untuk pengguna atau institusi yang membutuhkan **kontrol penuh atas data**, privasi tinggi, dan kemampuan integrasi fleksibel, sementara layanan cloud komersial lebih unggul untuk pengguna umum yang menginginkan kemudahan tanpa setup teknis.

---

## Kesimpulan & Saran

[⬆️ Kembali ke atas](#daftar-isi)

* Nextcloud cocok untuk kebutuhan kampus skala kecil sampai menengah dengan kontrol penuh atas data.
* Rekomendasi: gunakan SSD untuk data directory, atur backup otomatis, dan pantau resource secara periodik.
* Pengembangan lanjutan: integrasi OnlyOffice/Collabora untuk editing dokumen real-time, dan konfigurasi clustering untuk high-availability.

---

## Lampiran

[⬆️ Kembali ke atas](#daftar-isi)

* `docker-compose.yml` — konfigurasi service
* `diagram-arsitektur.jpg` — diagram topologi

---

## Referensi

[⬆️ Kembali ke atas](#daftar-isi)

* Dokumentasi resmi Nextcloud: [https://nextcloud.com](https://nextcloud.com)
* Dokumentasi Docker: [https://docs.docker.com](https://docs.docker.com)
