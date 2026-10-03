# JMeter Progressive Performance Test Runner

Automasi eksekusi pengujian performa Apache JMeter berbasis Command Line Interface (CLI) pada Windows Batch Script (`.bat`) dengan dukungan **Progressive / Step-up Stress Testing**, manajemen memori JVM, pemisahan log per tahap, serta pembuatan dashboard ringkasan HTML terpadu (*Master Summary Report*).

---

## 📋 Daftar Isi
1. [Latar Belakang & Masalah pada Kode Awal](#-latar-belakang--masalah-pada-kode-awal)
2. [Fitur & Peningkatan Utama](#-fitur--peningkatan-utama)
3. [Perbandingan Detail: `awal.bat` vs `test.bat`](#-perbandingan-detail-awalbat-vs-testbat)
4. [Detail Teknis & Arsitektur Script](#-detail-teknis--arsitektur-script)
5. [Prasyarat Sistem](#-prasyarat-sistem)
6. [Panduan Penggunaan](#-panduan-penggunaan)
7. [Struktur Folder & Hasil Pengujian](#-struktur-folder--hasil-pengujian)

---

## 🔍 Latar Belakang & Masalah pada Kode Awal

Pada versi awal (`awal.bat`), pengujian dijalankan dengan skenario statis:
1. **Nilai User Di-*hardcode***: Hanya bisa menjalankan 18 users lalu 30 users. Jika ingin menguji 10, 50, atau 100 users, script harus diedit manual setiap kali pengujian.
2. **Tidak Fleksibel**: Pengguna tidak dapat mengatur tahapan uji beban bertahap (*progressive / step-up load test*) secara dinamis dari terminal.
3. **Risiko Crash Memori JVM**: JMeter dijalankan dengan alokasi heap default Windows (~1 GB). Pada beban user yang tinggi atau pelaporan HTML besar, JMeter rentan mengalami `java.lang.OutOfMemoryError`.
4. **Log Saling Menimpa**: Seluruh log ditulis ke satu file `jmeter.log` global sehingga sulit menelusuri penyebab kegagalan di tahap tertentu.
5. **Dashboard Terpisah**: Laporan HTML dibuat per tahap dalam folder berbeda tanpa ada satu landing page ringkasan (*Master Index*) untuk melihat perbandingan hasil.
6. **Think Time Statis**: Jeda antar aksi user di-*hardcode* 1000ms tanpa opsi penyesuaian.

---

## ✨ Fitur & Peningkatan Utama

* **Multi-Stage Progressive Input**: Menerima input daftar target user bertahap sekaligus (misal: `10 20 30 50` atau `10, 20, 50`) maupun single test (`25`).
* **Optimasi Memory Java (`JVM_ARGS`)**: Mengalokasikan 2GB Heap dengan algoritma garbage collection modern (`-Xms2g -Xmx2g -XX:+UseG1GC`).
* **Pemisahan Log Terisolasi**: Setiap tahap memiliki file `.log` sendiri (`jmeter_stage1_...log`, `jmeter_stage2_...log`).
* **Executive Summary HTML Generator**: Otomatis membuat file `summary_<timestamp>.html` dengan tema gelap modern yang merangkum status seluruh tahap dan menyediakan tombol link langsung ke masing-masing dashboard HTML.
* **Cooldown Interaktif**: Jeda istirahat antar tahap menampilkan waktu hitung mundur dan dapat dilewati seketika (*skip*) dengan menekan tombol keyboard apapun.
* **Audio Notification**: Membunyikan nada dering ganda (*beep alert*) melalui PowerShell ketika seluruh rangkaian pengujian selesai.
* **Auto-Open Browser**: Opsi langsung membuka *Master Summary Dashboard* di browser default setelah pengujian rampung.

---

## ⚖️ Perbandingan Detail: `awal.bat` vs `test.bat`

| Aspek | `awal.bat` (Kode Awal) | `test.bat` (Progressive Runner) |
|---|---|---|
| **Jumlah User (Threads)** | Statis (18 lalu 30) | Dinamis bertahap via input pengguna |
| **Banyak Tahap Pengujian** | Maksimal 2 tahap tetap | Bebas (1 hingga $N$ tahap tak terbatas) |
| **Ramp-Up Time** | Statis 18s & 30s | Otomatis 1 detik/user per tahap |
| **Think Time** | Hardcode 1000ms | Interaktif (dapat disesuaikan) |
| **Memory Heap JVM** | Default sistem (~1GB) | 2GB Heap (`-Xms2g -Xmx2g -XX:+UseG1GC`) |
| **File Log JMeter** | 1 file global tertimpa | Log terpisah per tahap (`jmeter_stageX.log`) |
| **Laporan Akhir** | Folder terpisah tanpa index | *Master Summary Dashboard HTML* otomatis |
| **Notifikasi Selesai** | Hanya pause di command prompt | *Audio beep alert* + pop-up opsi browser |
| **Cooldown Antar Uji** | Statis diam tanpa feedback | Hitung mundur interaktif (bisa di-skip) |

---

## 🛠 Detail Teknis & Arsitektur Script

### 1. Loop Parsing Tahap Pengujian
Menggunakan fitur `setlocal EnableDelayedExpansion` pada Windows Batch:
```batch
for %%U in (%USER_LIST%) do (
    set /a CURRENT_STAGE+=1
    set "THREADS=%%U"
    set "RAMPUP=%%U"
    ...
)
```
Karakter pemisah seperti spasi (` `) atau koma (`,`) diparsing otomatis oleh batch loop sehingga input seperti `10 20 50` atau `10, 20, 50` diproses secara berurutan.

### 2. Parameter JMeter CLI
Perintah yang dieksekusi pada setiap tahap:
```batch
call "%JMETER_HOME%\bin\jmeter.bat" -n -t "%TEST_PLAN%" -j "!STAGE_LOG!" -Jthreads=!THREADS! -Jrampup=!RAMPUP! -Jloops=1 -JthinkTime=%THINK_TIME% -l "!JTL_FILE!" -e -o "!REPORT_DIR!"
```
* `-n` : Menjalankan JMeter dalam mode non-GUI (CLI).
* `-t` : Path file Test Plan JMeter (`.jmx`).
* `-j` : Path file log JMeter per tahap.
* `-Jthreads` : Variabel user threads yang disuntikkan ke Test Plan.
* `-Jrampup` : Waktu ramp-up (detik) per tahap.
* `-Jloops` : Jumlah iterasi per thread.
* `-JthinkTime` : Jeda waktu antar sampler (ms).
* `-l` : Lokasi file output log hasil uji (`.jtl`).
* `-e -o` : Otomatis membuat HTML Dashboard Report ke direktori tujuan.

---

## 💻 Prasyarat Sistem

1. **Sistem Operasi**: Windows 10 / 11 / Windows Server.
2. **Apache JMeter**: Versi 5.6.3 (terekstrak di `C:\apache-jmeter-5.6.3` atau sesuaikan variabel `JMETER_HOME`).
3. **Java**: JDK / JRE versi 8, 11, 17, atau 21 yang sudah terdaftar di `PATH`.
4. **File Test Plan**: File JMX `[CLI] PT_SMI_Perencanaan_dan_Permintaan_Pengadaan.jmx` diletakkan di direktori yang sama dengan script.

---

## 🚀 Panduan Penggunaan

1. Buka Command Prompt atau klik dua kali file **`test.bat`**.
2. Masukkan target user tahapan pengujian saat diminta:
   ```text
   >> Target Users: 10 20 30 50
   ```
3. Tentukan jeda istirahat (*cooldown*) antar tahap (atau tekan **Enter** untuk default 30 detik):
   ```text
   >> Jeda istirahat (cooldown) antar tahap dalam detik [Default: 30]: 30
   ```
4. Tentukan nilai *think time* (atau tekan **Enter** untuk default 1000ms):
   ```text
   >> Think time antar request dalam milidetik [Default: 1000ms]: 1000
   ```
5. Tekan tombol apa saja untuk memulai. Script akan mengeksekusi setiap tahap, menyusun log, membuat report HTML, membunyikan alarm saat selesai, dan menawarkan untuk membuka dashboard ringkasan di browser.

---

## 📂 Struktur Folder & Hasil Pengujian

Semua output otomatis tersimpan di dalam folder `results/`:

```text
menrey/
├── [CLI] PT_SMI_Perencanaan_dan_Permintaan_Pengadaan.jmx
├── test.bat                          # Progressive Test Runner (Terbaru)
├── awal.bat                          # Script versi awal (Referensi)
├── README.md
└── results/
    ├── summary_20261003_233000.html   # Master Summary Dashboard
    ├── jmeter_stage1_10users_....log  # Log JMeter Tahap 1
    ├── test_stage1_10users_....jtl    # Raw JTL Data Tahap 1
    └── report_stage1_10users_.../     # HTML Dashboard Tahap 1
        └── index.html
```
