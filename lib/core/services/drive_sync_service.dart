import 'dart:async';
import 'dart:io';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import 'google_auth_service.dart';

class BackupInfo {
  final bool exists;
  final DateTime? modifiedTime;
  final int? sizeBytes;
  final String? fileId;

  const BackupInfo({
    required this.exists,
    this.modifiedTime,
    this.sizeBytes,
    this.fileId,
  });
}

enum SyncProgress { idle, syncing, success, error }

class DriveSyncService {
  DriveSyncService._();
  static final DriveSyncService instance = DriveSyncService._();

  static const _backupFileName = 'tally_backup.db';
  static const _prefKeyLastSync = 'drive_last_sync_time';
  static const _prefKeyPendingChanges = 'drive_has_pending_changes';

  final _syncProgressController = StreamController<SyncProgress>.broadcast();
  Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;
  SyncProgress _currentProgress = SyncProgress.idle;
  SyncProgress get currentProgress => _currentProgress;

  Timer? _debounceTimer;
  Timer? _periodicTimer;
  bool _isSyncRunning = false;

  void initializePeriodicSync() {
    _periodicTimer?.cancel();
    // Cek setiap 3 menit: jika ada perubahan yang tertunda (misal tadi offline), sync otomatis
    _periodicTimer = Timer.periodic(const Duration(minutes: 3), (_) async {
      final hasPending = await hasPendingChanges();
      if (hasPending) {
        triggerBackgroundSync(immediate: true, isDataChange: false);
      }
    });
  }

  /// Cek koneksi internet sederhana via DNS lookup ke google.com
  Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Cek apakah ada perubahan data lokal yang belum tersinkron ke cloud
  Future<bool> hasPendingChanges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefKeyPendingChanges) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _setPendingChanges(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyPendingChanges, value);
    } catch (_) {
      // Aman di lingkungan unit test tanpa ServicesBinding
    }
  }

  Future<drive.DriveApi?> _getDriveApi() async {
    try {
      final user = await GoogleAuthService.instance.ensureAuthenticated();
      if (user == null) return null;

      final authz = await user.authorizationClient.authorizeScopes([drive.DriveApi.driveAppdataScope]);
      final authClient = authz.authClient(scopes: [drive.DriveApi.driveAppdataScope]);
      return drive.DriveApi(authClient);
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final epoch = prefs.getInt(_prefKeyLastSync);
      if (epoch == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(epoch);
    } catch (_) {
      return null;
    }
  }

  Future<void> _recordSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKeyLastSync, DateTime.now().millisecondsSinceEpoch);
      await prefs.setBool(_prefKeyPendingChanges, false);
    } catch (_) {}
  }

  /// Mengecek apakah ada file cadangan di Google Drive (appDataFolder)
  Future<BackupInfo> checkRemoteBackup() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return const BackupInfo(exists: false);

      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName' and trashed = false",
        $fields: 'files(id, name, modifiedTime, size)',
      );

      final files = fileList.files;
      if (files == null || files.isEmpty) {
        return const BackupInfo(exists: false);
      }

      final file = files.first;
      return BackupInfo(
        exists: true,
        fileId: file.id,
        modifiedTime: file.modifiedTime,
        sizeBytes: file.size != null ? int.tryParse(file.size!) : null,
      );
    } catch (_) {
      return const BackupInfo(exists: false);
    }
  }

  /// Mengunggah file database tally.db lokal ke Google Drive
  Future<bool> backupToDrive({bool force = false}) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        throw Exception('Belum login ke akun Google.');
      }

      // Checkpoint WAL agar seluruh transaksi yang di-commit tersimpan di file fisik utama tally.db
      try {
        final db = await DatabaseHelper.instance.database;
        await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      } catch (_) {}

      // Cegah menimpa cadangan cloud jika database lokal di HP ini kosong
      final isLocalEmpty = await DatabaseHelper.instance.isDatabaseEmpty();
      if (isLocalEmpty && !force) {
        final remote = await checkRemoteBackup();
        if (remote.exists) {
          throw Exception(
            'Data di HP ini masih kosong, sedangkan di Google Drive sudah ada data cadangan Anda. '
            'Pencadangan dibatalkan untuk melindungi data di cloud. Silakan gunakan "Pulihkan Data".',
          );
        }
      }

      final dbPath = await DatabaseHelper.instance.getDatabaseFilePath();
      final localFile = File(dbPath);
      if (!await localFile.exists()) {
        throw Exception('Database lokal tidak ditemukan.');
      }

      final fileLength = await localFile.length();
      final mediaStream = localFile.openRead();
      final uploadMedia = drive.Media(mediaStream, fileLength);

      // Cek apakah file sudah ada di appDataFolder
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName' and trashed = false",
        $fields: 'files(id, name)',
      );

      final files = fileList.files;
      if (files != null && files.isNotEmpty) {
        // Update file yang ada
        final existingFileId = files.first.id!;
        await driveApi.files.update(
          drive.File(),
          existingFileId,
          uploadMedia: uploadMedia,
        );
      } else {
        // Buat file baru di appDataFolder
        final newDriveFile = drive.File()
          ..name = _backupFileName
          ..parents = ['appDataFolder'];

        await driveApi.files.create(
          newDriveFile,
          uploadMedia: uploadMedia,
        );
      }

      await _recordSyncTime();
      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Helper untuk mengecek jumlah transaksi dari byte array database
  Future<int> _countTransactionsInBytes(List<int> bytes) async {
    try {
      final dbPath = await DatabaseHelper.instance.getDatabaseFilePath();
      final tempPath = join(dirname(dbPath), 'temp_tally_inspect.db');
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytes, flush: true);

      final db = await openReadOnlyDatabase(tempPath);
      final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM transactions');
      final count = Sqflite.firstIntValue(res) ?? 0;
      await db.close();

      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// Mengunduh file database dari Google Drive dan menimpa database lokal
  /// Memiliki fitur pemulihan revisi otomatis jika versi terbaru ternyata kosong.
  Future<bool> restoreFromDrive() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        throw Exception('Belum login ke akun Google.');
      }

      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName' and trashed = false",
        $fields: 'files(id, name)',
      );

      final files = fileList.files;
      if (files == null || files.isEmpty) {
        throw Exception('Tidak ditemukan file cadangan di Google Drive.');
      }

      final fileId = files.first.id!;

      // Unduh versi head/terbaru
      final driveMedia = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      List<int> downloadedBytes = [];
      await for (final chunk in driveMedia.stream) {
        downloadedBytes.addAll(chunk);
      }

      if (downloadedBytes.isEmpty) {
        throw Exception('File cadangan di Google Drive kosong.');
      }

      // Cek apakah revisi terbaru memiliki transaksi
      int txCount = await _countTransactionsInBytes(downloadedBytes);

      // Jika versi terbaru kosong (misal akibat tertimpa tidak sengaja saat install baru),
      // cari di daftar revisi sebelumnya yang memiliki transaksi!
      if (txCount == 0) {
        try {
          final revResponse = await driveApi.revisions.list(fileId);
          final revList = revResponse.revisions ?? [];
          for (final rev in revList.reversed) {
            try {
              final revMedia = await driveApi.revisions.get(
                fileId,
                rev.id!,
                downloadOptions: drive.DownloadOptions.fullMedia,
              ) as drive.Media;

              final List<int> candidateBytes = [];
              await for (final chunk in revMedia.stream) {
                candidateBytes.addAll(chunk);
              }

              final revCount = await _countTransactionsInBytes(candidateBytes);
              if (revCount > 0) {
                downloadedBytes = candidateBytes;
                txCount = revCount;
                break;
              }
            } catch (_) {}
          }
        } catch (_) {}
      }

      // Tutup koneksi database aktif sebelum menimpa file
      await DatabaseHelper.instance.closeDatabase();

      final dbPath = await DatabaseHelper.instance.getDatabaseFilePath();
      final localFile = File(dbPath);
      final journalFile = File('$dbPath-journal');
      final walFile = File('$dbPath-wal');
      final shmFile = File('$dbPath-shm');

      if (await journalFile.exists()) {
        try { await journalFile.delete(); } catch (_) {}
      }
      if (await walFile.exists()) {
        try { await walFile.delete(); } catch (_) {}
      }
      if (await shmFile.exists()) {
        try { await shmFile.delete(); } catch (_) {}
      }

      await localFile.writeAsBytes(downloadedBytes, flush: true);

      // Buka kembali database setelah ditimpa
      await DatabaseHelper.instance.reopenDatabase();

      await _recordSyncTime();
      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Sinkronisasi otomatis di latar belakang dengan debounce & retry saat online
  void triggerBackgroundSync({bool immediate = false, bool isDataChange = true}) {
    if (isDataChange) {
      unawaited(_setPendingChanges(true));
    }

    _debounceTimer?.cancel();

    if (immediate) {
      unawaited(_executeBackgroundSync());
    } else {
      // Debounce 2.5 detik agar aksi beruntun (misal tambah transaksi berturut-turut) digabung menjadi 1 kali upload
      _debounceTimer = Timer(const Duration(milliseconds: 2500), () {
        unawaited(_executeBackgroundSync());
      });
    }
  }

  Future<void> _executeBackgroundSync() async {
    if (_isSyncRunning) return;

    try {
      _isSyncRunning = true;

      // 1. Pastikan akun terhubung
      final account = await GoogleAuthService.instance.ensureAuthenticated();
      if (account == null) return;

      // 2. Cek koneksi internet
      final isOnline = await hasInternetConnection();
      if (!isOnline) {
        // Tetap tandai ada pending changes agar disinkronkan saat online kembali
        return;
      }

      // 3. Lindungi cadangan cloud: jangan auto-sync jika DB lokal masih kosong
      final isLocalEmpty = await DatabaseHelper.instance.isDatabaseEmpty();
      if (isLocalEmpty) return;

      // 4. Beritahu UI bahwa sinkronisasi sedang berjalan
      _currentProgress = SyncProgress.syncing;
      _syncProgressController.add(SyncProgress.syncing);

      final success = await backupToDrive();
      if (success) {
        await _setPendingChanges(false);
        _currentProgress = SyncProgress.success;
        _syncProgressController.add(SyncProgress.success);

        // Kembalikan ke idle setelah 2.5 detik
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (_currentProgress == SyncProgress.success) {
            _currentProgress = SyncProgress.idle;
            _syncProgressController.add(SyncProgress.idle);
          }
        });
      } else {
        _currentProgress = SyncProgress.idle;
        _syncProgressController.add(SyncProgress.idle);
      }
    } catch (_) {
      _currentProgress = SyncProgress.idle;
      _syncProgressController.add(SyncProgress.idle);
    } finally {
      _isSyncRunning = false;
    }
  }
}
