# Strategi Branching & Alur Pengembangan Tally

Dokumen ini memuat panduan alur kerja Git (Git Workflow), konvensi penamaan branch, serta rincian checklist tugas untuk pengembangan MVP **Tally** sesuai dengan [PRD.md](../PRD.md).

---

## 1. Aturan & Konvensi Branching

* **Branch Utama (`main`)**:
  * Berisi kode stabil yang siap di-run/produksi.
  * Dilindungi (protected); tidak melakukan commit langsung ke `main`.
* **Branch Fitur (`feat/<nama-fitur>`)**:
  * Dibuat dari branch `main` terbaru.
  * Bersifat granular (fokus pada satu modul fungsional).
  * Setelah selesai dan lolos tes (`flutter analyze` & `flutter test`), di-merge kembali ke `main`.
* **Konvensi Commit (Conventional Commits)**:
  * `feat: <deskripsi>`: Menambah fitur baru.
  * `fix: <deskripsi>`: Memperbaiki bug.
  * `refactor: <deskripsi>`: Mengubah struktur kode tanpa mengubah fungsi.
  * `test: <deskripsi>`: Menambah atau memperbarui pengujian.
  * `docs: <deskripsi>`: Dokumentasi proyek.

---

## 2. Roadmap Branching & Rincian Tugas

Berikut adalah daftar branch fungsional (Opsi A - Granular) beserta ruang lingkupnya:

```
main
 ├── feat/init-and-design-system      [SELESAI - MERGED]
 ├── feat/foundation-and-navigation   [AKTIF / BERIKUTNYA]
 ├── feat/wallets                     [MENDATANG]
 ├── feat/daily-budgets               [MENDATANG]
 ├── feat/transactions                [MENDATANG]
 ├── feat/dashboard                   [MENDATANG]
 └── feat/history                     [MENDATANG]
```

---

### 🟢 0. `feat/init-and-design-system`
* **Status:** Selesai & Merged ke `main`
* **Ruang Lingkup:**
  - [x] Inisialisasi proyek Flutter (Dart 3, Flutter 3).
  - [x] Konfigurasi dependensi (`riverpod`, `go_router`, `sqflite`, `intl`, dll).
  - [x] Tema monokrom hitam & putih ([app_theme.dart](../lib/core/theme/app_theme.dart)).
  - [x] Implementasi Splash Screen 1 detik dengan logo Tally.
  - [x] Konfigurasi App Launcher Icon (Android adaptive & legacy icon).
  - [x] Bottom navigation bar monokrom melayang.
  - [x] Dokumen PRD v1.0.

---

### 🟢 1. `feat/foundation-and-navigation`
* **Status:** Selesai (Lolos Uji & Siap di-merge ke `main`)
* **Tujuan:** Menyelaraskan skema database SQLite dengan PRD Bab 8 dan menyempurnakan struktur navigasi.
* **Checklist Tugas:**
  - [x] Perbarui tabel SQLite di [database_helper.dart](../lib/core/database/database_helper.dart):
    - `wallets`: `id` (UUID), `name`, `type`, `opening_balance` (IDR integer), `color`, `icon`, `is_archived`, timestamp.
    - `categories`: `id` (UUID), `name`, `type` (`income`/`expense`), `icon`, `color`, `is_archived`.
    - `daily_budgets`: `id` (UUID), `name`, `daily_limit` (IDR integer), `start_date`, `end_date`, `is_active`, timestamp.
    - `transactions`: `id` (UUID), `type`, `amount` (IDR integer), `category_id`, `wallet_id`, `source_wallet_id`, `destination_wallet_id`, `budget_id`, `occurred_at`, `local_date`, `note`, timestamp.
  - [x] Sesuaikan model data di `lib/shared/models/` sesuai skema database.
  - [x] Tambahkan Repository (`WalletRepository`, `TransactionRepository`, `BudgetRepository`, `CategoryRepository`).
  - [x] Ganti tab ke-4 dari **Laporan** menjadi **Kuota** (`/budgets`) di:
    - [main_scaffold.dart](../lib/shared/widgets/main_scaffold.dart)
    - [app_router.dart](../lib/core/router/app_router.dart)
  - [x] Buat skeleton screen untuk `BudgetsScreen` di `lib/features/budgets/presentation/budgets_screen.dart`.
  - [x] Tambahkan unit test di `test/foundation_test.dart` dan jalankan `flutter test` + `flutter analyze` (100% passed).

---

### 🟢 2. `feat/wallets`
* **Status:** Selesai (Lolos Uji & Siap di-merge ke `main`)
* **Tujuan:** Pengelolaan dompet (wallet) pengguna beserta perhitungan saldo.
* **Checklist Tugas:**
  - [x] Repository & Riverpod Provider untuk Wallet (`wallet_repository.dart`, `wallet_providers.dart`).
  - [x] Tampilan halaman Wallet ([wallets_screen.dart](../lib/features/wallets/presentation/wallets_screen.dart)):
    - Hero Card ringkasan total saldo saat ini (`totalActiveBalanceProvider`).
    - List kartu wallet (nama, jenis: Tunai/Bank/E-wallet/Lainnya, saldo).
    - Tab filter Dompet Aktif vs Diarsipkan.
  - [x] Bottom Sheet Tambah & Edit Wallet ([wallet_form_sheet.dart](../lib/features/wallets/presentation/widgets/wallet_form_sheet.dart)):
    - Input nama wallet.
    - Pilihan jenis wallet (Tunai, Bank, E-Wallet, Lainnya).
    - Input saldo awal Rupiah (live format).
  - [x] Aksi arsipkan/pulihkan wallet (tidak menghapus riwayat transaksi) & konfirmasi hapus.
  - [x] Unit test untuk CRUD dan eksklusi saldo arsip di `test/wallet_test.dart` (100% passed).

---

### 🟢 3. `feat/daily-budgets`
* **Status:** Selesai (Lolos Uji & Siap di-merge ke `main`)
* **Tujuan:** Pengelolaan kuota belanja harian tanpa rollover.
* **Checklist Tugas:**
  - [x] Repository & Riverpod Provider untuk Daily Budget (`budget_repository.dart`, `budget_providers.dart`).
  - [x] Tampilan halaman Kuota ([budgets_screen.dart](../lib/features/budgets/presentation/budgets_screen.dart)):
    - Hero Card ringkasan total kuota harian, terpakai, dan sisa hari ini (`dailyBudgetSummaryProvider`).
    - List kartu kuota aktif (nama, batas harian, progress bar, dan badge *over-budget*).
    - Tab filter Kuota Aktif vs Nonaktif.
  - [x] Bottom Sheet Tambah & Edit Kuota ([budget_form_sheet.dart](../lib/features/budgets/presentation/widgets/budget_form_sheet.dart)):
    - Input nama kuota & chip saran cepat ("Makan", "Kopi & Jajan", dll).
    - Input batas nominal harian Rupiah (live format).
    - Catatan edukatif reset harian tanpa rollover.
  - [x] Aksi aktifkan/nonaktifkan kuota & konfirmasi hapus.
  - [x] Unit test CRUD kuota harian di `test/budget_test.dart` (100% passed).

---

### ⚪ 4. `feat/transactions`
* **Status:** Mendatang
* **Tujuan:** Form pencatatan transaksi (Pemasukan, Pengeluaran, Transfer) dengan atomic update saldo.
* **Checklist Tugas:**
  - [ ] Form input transaksi modal / screen:
    - Tab pilihan jenis: **Pemasukan**, **Pengeluaran**, **Transfer**.
    - Input nominal (format IDR).
    - Picker tanggal & waktu (default: waktu sekarang).
    - Dropdown / picker Wallet (atau Wallet Asal & Tujuan untuk transfer).
    - Dropdown Kategori (opsional).
    - Dropdown Kuota Harian (khusus Pengeluaran, opsional/bisa "Tanpa Kuota").
    - Input catatan (opsional).
  - [ ] Validasi bisnis:
    - Nominal harus > 0.
    - Transfer: wallet sumber dan tujuan tidak boleh sama.
    - Peringatan jika pengeluaran melebihi sisa kuota harian (tetap diizinkan simpan).
  - [ ] Atomic database transaction: saldo wallet diperbarui secara konsisten.
  - [ ] Unit test skenario: Pemasukan, Pengeluaran, Transfer, dan Over-budget warning.

---

### ⚪ 5. `feat/dashboard`
* **Status:** Mendatang
* **Tujuan:** Tampilan beranda interaktif berbasis tanggal.
* **Checklist Tugas:**
  - [ ] Date picker & tombol navigasi hari sebelumnya/berikutnya.
  - [ ] Kartu ringkasan harian:
    - Total Pemasukan tanggal terpilih.
    - Total Pengeluaran tanggal terpilih.
    - Saldo Akhir Historis per tanggal terpilih.
  - [ ] Progress / indikator penggunaan Kuota Harian pada tanggal terpilih.
  - [ ] List transaksi pada tanggal terpilih.
  - [ ] Floating Action Button (FAB) `+` untuk membuka form pencatatan transaksi.
  - [ ] Tap transaksi untuk membuka detail / edit transaksi.

---

### ⚪ 6. `feat/history`
* **Status:** Mendatang
* **Tujuan:** Penelusuran riwayat transaksi lintas waktu, filter, dan edit/hapus.
* **Checklist Tugas:**
  - [ ] Daftar transaksi terkelompok per tanggal (group by date).
  - [ ] Bar pencarian instan (search by note / category / wallet).
  - [ ] Filter dialog:
    - Rentang tanggal (range picker).
    - Jenis transaksi (Semua / Pemasukan / Pengeluaran / Transfer).
    - Filter berdasarkan wallet tertentu.
  - [ ] Aksi Edit & Hapus Transaksi (menghitung ulang saldo dan kuota secara otomatis).
  - [ ] Konfirmasi dialog sebelum menghapus transaksi.

---

## 3. SOP Alur Kerja Git (Git Workflow)

Setiap mengerjakan satu fitur, ikuti urutan perintah berikut:

### Langkah A: Buat Branch Baru dari `main`
```bash
# Pastikan berada di main dan sudah up-to-date
git checkout main
git pull origin main

# Buat branch fitur baru
git checkout -b feat/<nama-fitur>
```

### Langkah B: Commit Pekerjaan
```bash
git add .
git commit -m "feat(<nama-fitur>): <deskripsi singkat perubahan>"
```

### Langkah C: Validasi Sebelum Merge
Pastikan tidak ada issue atau test yang gagal:
```bash
flutter analyze
flutter test
```

### Langkah D: Push & Merge ke `main`
```bash
# Push branch fitur ke remote
git push -u origin feat/<nama-fitur>

# Merge ke main:
git checkout main
git merge feat/<nama-fitur>
git push origin main
```
