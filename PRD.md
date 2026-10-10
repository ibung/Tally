# Tally --- Product Requirements Document (PRD)

**Versi:** 1.0\
**Tanggal:** 10 Oktober 2026\
**Status:** Draft MVP\
**Platform:** Flutter (Android/iOS)\
**Penyimpanan:** Lokal di perangkat, offline-first

## 1. Ringkasan Produk

**Tally** adalah aplikasi pencatat keuangan pribadi untuk mencatat
pemasukan, pengeluaran, transfer antar-wallet, serta memantau kuota
pengeluaran harian. Tally mengutamakan pencatatan yang cepat, tampilan
yang jelas, dan penyimpanan lokal tanpa mewajibkan koneksi internet.

Inspirasi desain: Sepran Expense Manager. Ini merupakan referensi arah
visual dan pengalaman pengguna, bukan tujuan untuk menyalin aset atau
implementasi secara persis.

### Masalah

-   Pengguna sulit melacak arus uang harian jika transaksi tidak
    dicatat.
-   Uang tersebar di beberapa wallet, seperti tunai, rekening bank, dan
    e-wallet.
-   Pengeluaran harian mudah melewati batas karena sisa kuota tidak
    terlihat.
-   Transaksi lama perlu mudah dicari.

### Solusi

Dashboard berdasarkan tanggal, pencatatan transaksi, pengelolaan wallet,
riwayat sederhana, dan kuota harian yang dipilih secara manual ketika
mencatat pengeluaran.

## 2. Tujuan dan Ukuran Keberhasilan

### Tujuan MVP

1.  Mencatat pemasukan, pengeluaran, dan transfer.
2.  Menampilkan pemasukan, pengeluaran, dan saldo untuk tanggal
    terpilih.
3.  Mengelola saldo beberapa wallet.
4.  Memantau kuota harian tanpa rollover.
5.  Menyimpan dan menelusuri transaksi secara lokal.

### Indikator keberhasilan

-   Transaksi bisa ditambah, diedit, dan dihapus tanpa kehilangan data.
-   Perhitungan saldo dan kuota konsisten.
-   Data tetap ada setelah aplikasi ditutup dan dibuka kembali.
-   Fitur inti berjalan tanpa internet.
-   Riwayat dapat ditelusuri dengan pencarian dan filter dasar.

## 3. Target Pengguna

Individu yang ingin mencatat keuangan harian, memisahkan uang di
beberapa tempat, menetapkan batas belanja harian (misalnya Rp25.000
untuk makan), dan meninjau transaksi tanggal sebelumnya dengan aplikasi
sederhana.

## 4. Prinsip Produk

-   **Local-first:** data utama tersimpan di perangkat.
-   **Cepat:** formulir transaksi sesingkat mungkin.
-   **Jelas:** income, expense, transfer, saldo, dan kuota tidak
    tercampur.
-   **Konsisten:** saldo dan kuota dihitung dari transaksi sumber.
-   **Tidak menghakimi:** transaksi yang melewati kuota tetap dapat
    disimpan dengan peringatan.
-   **MVP terfokus:** sinkronisasi cloud dan analitik lanjutan ditunda.

## 5. Ruang Lingkup

### Termasuk dalam MVP (P0)

1.  **Dashboard harian:** pilih tanggal; lihat total pemasukan,
    pengeluaran, saldo akhir historis, ringkasan kuota, dan transaksi
    pada tanggal itu; navigasi tanggal sebelumnya/berikutnya.
2.  **Transaksi:** CRUD pemasukan, pengeluaran, dan transfer; nominal,
    tanggal/waktu, wallet, kategori opsional, catatan opsional; kuota
    dapat dipilih manual untuk pengeluaran.
3.  **Wallet:** tambah/edit/arsipkan wallet, tentukan saldo awal, lihat
    saldo per wallet dan total saldo saat ini.
4.  **Kuota harian:** buat kuota bernama dengan batas harian; pilih
    manual saat mencatat pengeluaran; tampilkan batas, terpakai, dan
    sisa; reset tiap hari tanpa rollover; beri peringatan saat melebihi
    batas.
5.  **Kategori dasar:** kategori pemasukan dan pengeluaran, dengan
    kategori awal yang bisa dipilih.
6.  **Riwayat:** daftar lintas tanggal; pencarian berdasarkan
    catatan/kategori/wallet; filter tanggal, jenis transaksi, dan
    wallet; edit/hapus transaksi.
7.  **Penyimpanan lokal:** data persisten dan tidak memerlukan akun atau
    internet.

### Tidak termasuk dalam MVP

-   Login, akun, dan sinkronisasi cloud.
-   Integrasi bank/e-wallet otomatis.
-   Multi-currency.
-   Rollover kuota.
-   Pengingat/notifikasi terjadwal.
-   Grafik dan analitik kompleks, prediksi AI.
-   Ekspor/impor CSV atau PDF.
-   Kolaborasi antar-pengguna.
-   Web/desktop app.

Laporan dan grafik direncanakan setelah fitur dasar stabil.

## 6. Navigasi dan Layar

Navigasi bawah yang diusulkan: - **Beranda:** ringkasan tanggal
terpilih, kuota, transaksi harian. - **Riwayat:** pencarian dan filter
transaksi. - **Wallet:** wallet dan saldo. - **Kuota:** daftar kuota dan
pengaturan batas harian.

### Beranda

-   Pemilih tanggal dan navigasi hari.
-   Kartu pemasukan, pengeluaran, dan saldo akhir.
-   Ringkasan kuota: batas, terpakai, sisa.
-   Daftar transaksi pada tanggal terpilih.
-   Tombol tambah transaksi.

### Form transaksi

-   Jenis transaksi, nominal, tanggal/waktu.
-   Wallet untuk income/expense atau wallet sumber dan tujuan untuk
    transfer.
-   Kategori (opsional untuk income/expense).
-   Kuota harian (opsional, khusus expense).
-   Catatan (opsional).

### Riwayat

Daftar transaksi lintas tanggal, pencarian, filter, serta aksi melihat
detail, mengedit, dan menghapus.

### Wallet dan Kuota

Wallet menampilkan nama dan saldo, dengan fungsi tambah/edit/arsip.
Kuota menampilkan nama, batas harian, status, dan penggunaan pada
tanggal terpilih. Mengarsipkan item tidak menghapus histori transaksi.

## 7. Aturan Bisnis

### Pemasukan

-   Menambah saldo wallet yang dipilih.
-   Masuk ke total pemasukan pada tanggal transaksi.

### Pengeluaran

-   Mengurangi saldo wallet yang dipilih.
-   Masuk ke total pengeluaran pada tanggal transaksi.
-   Dapat terhubung ke maksimal satu kuota atau tidak menggunakan kuota.
-   Jika kuota dipilih, nominalnya dihitung ke penggunaan kuota tersebut
    pada tanggal transaksi.

### Transfer

-   Memiliki wallet sumber dan tujuan yang berbeda.
-   Mengurangi saldo sumber dan menambah saldo tujuan.
-   Tidak dihitung sebagai pemasukan atau pengeluaran.
-   Tidak mengubah total saldo seluruh wallet.

### Saldo wallet

`Saldo = saldo awal + pemasukan - pengeluaran + transfer masuk - transfer keluar`

Saldo sebaiknya dihitung dari transaksi sumber agar konsisten. Jika
kelak memakai cache untuk performa, cache harus dapat direkonsiliasi.

### Dashboard historis

-   Pemasukan dan pengeluaran harian hanya menghitung transaksi pada
    tanggal terpilih.
-   Saldo akhir historis adalah saldo setelah seluruh transaksi sampai
    akhir tanggal terpilih, memperhitungkan saldo awal.
-   Total saldo saat ini di halaman Wallet menggunakan seluruh transaksi
    hingga saat ini.
-   Label "Saldo akhir tanggal" dan "Total saldo saat ini" harus
    dibedakan.

### Kuota harian

-   Pengguna membuat kuota dengan nama dan batas per hari.
-   Kuota dipilih manual saat membuat/mengedit pengeluaran.
-   Penggunaan kuota = jumlah pengeluaran yang terhubung ke kuota itu
    pada tanggal lokal yang sama.
-   Sisa = batas harian − penggunaan.
-   Tidak ada rollover; hari baru memulai perhitungan penggunaan dari
    nol.
-   Kuota terlampaui menghasilkan peringatan, tetapi transaksi tetap
    bisa disimpan.
-   Edit, hapus, atau perubahan tanggal transaksi harus menghitung ulang
    penggunaan kuota.
-   Transaksi yang dipindah tanggal dihitung pada tanggal barunya.

### Tanggal dan nominal

-   Tanggal kuota mengikuti kalender lokal perangkat.
-   Transaksi retrospektif menggunakan tanggal yang dipilih, bukan
    tanggal saat dicatat.
-   Nominal Rupiah disimpan sebagai integer, bukan floating point.
-   Nominal transaksi harus lebih besar dari nol.
-   Tampilan menggunakan format lokal Indonesia, misalnya `Rp25.000`.

### Arsip

-   Wallet yang punya histori sebaiknya diarsipkan, bukan dihapus
    permanen.
-   Wallet/kuota/kategori yang dinonaktifkan tidak ditawarkan untuk
    transaksi baru, tetapi referensi historis tetap dipertahankan.

## 8. Model Data Awal

Rancangan berikut untuk SQLite dan dapat disesuaikan saat implementasi.

### `wallets`

  Field                        Tipe/ketentuan           Keterangan
  ---------------------------- ------------------------ -----------------------------
  `id`                         TEXT/UUID, primary key   ID wallet
  `name`                       TEXT, wajib              Nama wallet
  `type`                       TEXT                     cash, bank, e-wallet, other
  `opening_balance`            INTEGER                  Saldo awal Rupiah
  `color`                      TEXT, opsional           Warna UI
  `icon`                       TEXT, opsional           Ikon
  `is_archived`                INTEGER/boolean          Status arsip
  `created_at`, `updated_at`   TEXT/datetime            Timestamp

### `categories`

  Field             Tipe/ketentuan           Keterangan
  ----------------- ------------------------ ---------------------
  `id`              TEXT/UUID, primary key   ID kategori
  `name`            TEXT, wajib              Nama kategori
  `type`            TEXT                     income atau expense
  `icon`, `color`   TEXT, opsional           Tampilan
  `is_archived`     INTEGER/boolean          Status arsip

### `daily_budgets`

  Field                        Tipe/ketentuan           Keterangan
  ---------------------------- ------------------------ ------------------------
  `id`                         TEXT/UUID, primary key   ID kuota
  `name`                       TEXT, wajib              Misalnya Makan
  `daily_limit`                INTEGER, wajib           Batas harian Rupiah
  `start_date`                 TEXT/date                Tanggal mulai
  `end_date`                   TEXT/date, nullable      Tanggal akhir opsional
  `is_active`                  INTEGER/boolean          Aktif/nonaktif
  `created_at`, `updated_at`   TEXT/datetime            Timestamp

### `transactions`

  Field                        Tipe/ketentuan           Keterangan
  ---------------------------- ------------------------ ---------------------------
  `id`                         TEXT/UUID, primary key   ID transaksi
  `type`                       TEXT                     income, expense, transfer
  `amount`                     INTEGER, wajib           Nominal Rupiah positif
  `category_id`                TEXT, nullable           Kategori income/expense
  `wallet_id`                  TEXT, nullable           Wallet income/expense
  `source_wallet_id`           TEXT, nullable           Wallet sumber transfer
  `destination_wallet_id`      TEXT, nullable           Wallet tujuan transfer
  `budget_id`                  TEXT, nullable           Kuota untuk expense
  `occurred_at`                TEXT/datetime            Waktu transaksi
  `local_date`                 TEXT/date                Tanggal lokal transaksi
  `note`                       TEXT, nullable           Catatan
  `created_at`, `updated_at`   TEXT/datetime            Timestamp

Validasi aplikasi memastikan `wallet_id` dipakai untuk income/expense
dan `source_wallet_id`/`destination_wallet_id` dipakai untuk transfer.

## 9. Teknologi yang Direncanakan

-   **Framework:** Flutter + Dart null safety.
-   **Database:** SQLite melalui `sqflite` atau alternatif setara.
-   **State management:** Riverpod.
-   **Navigasi:** `go_router` atau navigasi Flutter yang sesuai.
-   **Tanggal dan format angka:** `intl`.
-   **Grafik:** tidak dibutuhkan di MVP; `fl_chart` bisa dievaluasi
    nanti.

Versi paket dan arsitektur final ditentukan saat setup proyek
berdasarkan versi stabil yang tersedia.

## 10. Alur Pengguna

### Mencatat pengeluaran dengan kuota

1.  Tekan tambah transaksi dan pilih Pengeluaran.
2.  Isi nominal, tanggal, wallet, kategori jika perlu.
3.  Pilih satu kuota secara manual atau pilih Tanpa kuota.
4.  Aplikasi menunjukkan perkiraan sisa kuota.
5.  Jika melewati batas, tampilkan peringatan tetapi izinkan
    penyimpanan.
6.  Setelah disimpan, dashboard, saldo, riwayat, dan kuota diperbarui.

### Mencatat transfer

1.  Pilih Transfer.
2.  Pilih wallet sumber dan tujuan yang berbeda.
3.  Isi nominal, tanggal, dan catatan opsional.
4.  Simpan; saldo dua wallet berubah, tetapi income/expense tidak
    bertambah.

### Melihat tanggal sebelumnya

1.  Buka Beranda lalu pilih tanggal.
2.  Tampilkan pemasukan, pengeluaran, saldo akhir historis, transaksi,
    dan kuota pada tanggal tersebut.
3.  Pengguna dapat membuka transaksi untuk melihat detail atau
    mengeditnya.

### Mengedit/menghapus transaksi

1.  Buka transaksi dari Beranda atau Riwayat.
2.  Edit dan simpan, atau konfirmasi penghapusan.
3.  Hitung ulang saldo dan kuota dari transaksi terbaru.

## 11. Kebutuhan Fungsional dan Acceptance Criteria

### F-01 Dashboard

-   [ ] Pengguna dapat memilih tanggal.
-   [ ] Pemasukan/pengeluaran hanya menghitung transaksi pada tanggal
    terpilih.
-   [ ] Saldo akhir historis memperhitungkan saldo awal dan transaksi
    sampai akhir tanggal itu.
-   [ ] Daftar transaksi cocok dengan tanggal terpilih.

### F-02 Pemasukan

-   [ ] Pemasukan dapat dibuat, dilihat, diedit, dan dihapus.
-   [ ] Pemasukan menambah saldo wallet yang dipilih.

### F-03 Pengeluaran

-   [ ] Pengeluaran dapat dibuat, dilihat, diedit, dan dihapus.
-   [ ] Pengeluaran mengurangi saldo wallet.
-   [ ] Pengeluaran dapat memakai maksimal satu kuota.
-   [ ] Pengeluaran di atas batas tetap tersimpan dengan peringatan.

### F-04 Transfer

-   [ ] Wallet sumber dan tujuan harus berbeda.
-   [ ] Saldo sumber turun dan tujuan naik.
-   [ ] Transfer tidak dihitung sebagai income/expense dan tidak
    mengubah total saldo.

### F-05 Wallet

-   [ ] Wallet dapat dibuat dengan nama dan saldo awal.
-   [ ] Saldo dihitung konsisten dari saldo awal dan transaksi.
-   [ ] Wallet dengan histori dapat diarsipkan.
-   [ ] Total saldo saat ini dijelaskan secara konsisten, termasuk
    perlakuan wallet yang diarsipkan.

### F-06 Kuota

-   [ ] Kuota dapat dibuat dengan nama dan batas harian.
-   [ ] Kuota dipilih manual pada form pengeluaran.
-   [ ] Penggunaan dihitung per tanggal lokal.
-   [ ] Tidak ada rollover.
-   [ ] Edit/hapus/perubahan tanggal memperbarui pemakaian.
-   [ ] Status melebihi batas terlihat jelas.

### F-07 Riwayat

-   [ ] Pengguna dapat melihat transaksi lintas tanggal.
-   [ ] Pencarian teks dan filter tanggal, jenis, serta wallet tersedia.
-   [ ] Transaksi dapat dibuka, diedit, dan dihapus dari riwayat.

### F-08 Offline dan persistensi

-   [ ] Data tetap ada setelah aplikasi dimulai ulang.
-   [ ] Fitur inti berjalan tanpa internet.
-   [ ] Penekanan tombol simpan berulang tidak membuat duplikasi
    transaksi.

## 12. Kebutuhan Nonfungsional

-   **Reliabilitas:** operasi database konsisten; transfer dilakukan
    dalam satu transaksi database.
-   **Performa:** dashboard dan riwayat tetap responsif untuk volume
    transaksi pribadi yang wajar.
-   **Privasi:** data keuangan disimpan lokal dan tidak dikirim ke
    server pada MVP.
-   **Usability:** input cepat, label jelas, dan konfirmasi untuk aksi
    destruktif.
-   **Maintainability:** logika saldo/kuota dipisahkan dari UI dan
    diuji.
-   **Aksesibilitas dasar:** kontras memadai, target sentuh cukup besar,
    status tidak hanya dibedakan dengan warna.

## 13. Pengujian Minimum

1.  Pemasukan meningkatkan saldo wallet.
2.  Pengeluaran mengurangi saldo wallet.
3.  Transfer mempertahankan total saldo.
4.  Dashboard historis menampilkan saldo akhir yang benar.
5.  Pengeluaran berkuota memperbarui penggunaan pada tanggal yang
    sesuai.
6.  Pengeluaran tanpa kuota tidak mengubah penggunaan kuota.
7.  Pengeluaran di atas batas tetap tersimpan dan memberi peringatan.
8.  Edit/hapus transaksi memperbarui saldo dan kuota.
9.  Mengubah tanggal transaksi memindahkan dampaknya ke tanggal baru.
10. Data tetap ada setelah aplikasi dibuka ulang.
11. Wallet sumber dan tujuan transfer tidak bisa sama.
12. Format Rupiah benar dan tidak mengalami kesalahan pembulatan.

## 14. Roadmap Implementasi

### Fase 1 --- Fondasi

-   Setup Flutter dan struktur folder.
-   Setup SQLite dan migrasi awal.
-   CRUD wallet dan kategori.
-   Logika saldo dan tes dasar.

### Fase 2 --- Transaksi dan dashboard

-   CRUD pemasukan, pengeluaran, dan transfer.
-   Dashboard harian dan navigasi tanggal.
-   Perhitungan saldo historis.
-   Riwayat dan pencarian/filter dasar.

### Fase 3 --- Kuota harian

-   CRUD kuota.
-   Pilihan kuota manual di form pengeluaran.
-   Tampilan batas, terpakai, dan sisa.
-   Peringatan over-budget.
-   Tes edit, hapus, dan perubahan tanggal.

### Fase 4 --- Stabilisasi MVP

-   Penyempurnaan UI/UX.
-   Validasi dan penanganan error.
-   Pengujian persistensi dan konsistensi data.
-   Build untuk perangkat target.

## 15. Risiko dan Keputusan Rekomendasi

1.  **Saldo negatif:** izinkan transaksi yang membuat saldo negatif,
    tetapi tandai dengan jelas.
2.  **Saldo awal:** dianggap sebagai saldo pada awal penggunaan
    aplikasi; histori sebelum tanggal mulai pencatatan memiliki
    keterbatasan.
3.  **Arsip wallet:** wallet yang diarsipkan tidak tersedia untuk
    transaksi baru secara default, histori tetap dapat dilihat.
4.  **Kuota nonaktif:** transaksi lama tetap mempertahankan relasi ke
    kuota.
5.  **Grafik/laporan:** ditunda hingga transaksi, saldo, dan kuota
    stabil.

## 16. Definition of Done

MVP Tally selesai ketika: - Acceptance criteria P0 lulus pengujian. -
Pemasukan, pengeluaran, dan transfer dapat dikelola. - Saldo wallet,
dashboard historis, dan kuota konsisten. - Kuota dipilih manual, reset
setiap hari, dan tanpa rollover. - Riwayat serta pencarian/filter dasar
berfungsi. - Data persisten dan fitur inti offline. - Tidak ada bug
kritis yang menyebabkan kehilangan data atau perhitungan saldo salah. -
Build aplikasi berjalan pada perangkat target.

## 17. Riwayat Dokumen

-   **v1.0 --- 10 Oktober 2026:** Draft PRD MVP pertama menggunakan nama
    produk **Tally**. Ruang lingkup: dashboard harian, transaksi,
    wallet, kuota harian manual tanpa rollover, dan riwayat sederhana.
