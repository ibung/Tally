import 'dart:async';
import 'dart:io';
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
  static const _prefKeyLastRemoteModified = 'drive_last_remote_modified';

  final _syncProgressController = StreamController<SyncProgress>.broadcast();
  Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;
  SyncProgress _currentProgress = SyncProgress.idle;
  SyncProgress get currentProgress => _currentProgress;

  final _dataUpdatedController = StreamController<void>.broadcast();
  Stream<void> get dataUpdatedStream => _dataUpdatedController.stream;

  Timer? _debounceTimer;
  Timer? _periodicTimer;
  bool _isSyncRunning = false;

  void initializePeriodicSync() {
    _periodicTimer?.cancel();
    // Cek setiap 3 menit: sync otomatis untuk mendeteksi perubahan dari HP lain atau perubahan tertunda
    _periodicTimer = Timer.periodic(const Duration(minutes: 3), (_) async {
      triggerBackgroundSync(immediate: true, isDataChange: false);
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

  drive.DriveApi? _cachedDriveApi;
  DateTime? _cachedDriveApiTime;

  void setCachedDriveClient(dynamic authClient) {
    if (authClient != null) {
      _cachedDriveApi = drive.DriveApi(authClient);
      _cachedDriveApiTime = DateTime.now();
    }
  }

  void invalidateCachedDriveApi() {
    _cachedDriveApi = null;
    _cachedDriveApiTime = null;
  }

  Future<drive.DriveApi?> _getDriveApi({bool interactive = false}) async {
    try {
      if (_cachedDriveApi != null &&
          _cachedDriveApiTime != null &&
          DateTime.now().difference(_cachedDriveApiTime!).inMinutes < 45) {
        return _cachedDriveApi;
      }

      final authClient = await GoogleAuthService.instance.getDriveAuthClient(
        interactive: interactive,
      );
      if (authClient == null) return null;

      _cachedDriveApi = drive.DriveApi(authClient);
      _cachedDriveApiTime = DateTime.now();
      return _cachedDriveApi;
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

  Future<void> _recordSyncTime({DateTime? remoteModified}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKeyLastSync, DateTime.now().millisecondsSinceEpoch);
      await prefs.setBool(_prefKeyPendingChanges, false);
      if (remoteModified != null) {
        await prefs.setInt(_prefKeyLastRemoteModified, remoteModified.millisecondsSinceEpoch);
      }
    } catch (_) {}
  }

  /// Mengecek apakah ada file cadangan di Google Drive (appDataFolder)
  Future<BackupInfo> checkRemoteBackup({bool interactive = false}) async {
    try {
      final driveApi = await _getDriveApi(interactive: interactive);
      if (driveApi == null) return const BackupInfo(exists: false);

      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName' and trashed = false",
        orderBy: 'modifiedTime desc',
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
  Future<bool> backupToDrive({bool force = false, bool interactive = false}) async {
    try {
      final isOnline = await hasInternetConnection();
      if (!isOnline) {
        throw Exception('Tidak ada koneksi internet.');
      }

      final driveApi = await _getDriveApi(interactive: interactive);
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
        final remote = await checkRemoteBackup(interactive: interactive);
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
        orderBy: 'modifiedTime desc',
        $fields: 'files(id, name, modifiedTime)',
      );

      final files = fileList.files;
      drive.File uploadedFile;
      if (files != null && files.isNotEmpty) {
        // Update file yang ada
        final existingFileId = files.first.id!;
        uploadedFile = await driveApi.files.update(
          drive.File(),
          existingFileId,
          uploadMedia: uploadMedia,
          $fields: 'id, name, modifiedTime',
        );

        // Bersihkan duplikat file lama jika ada lebih dari 1
        for (int i = 1; i < files.length; i++) {
          try {
            await driveApi.files.delete(files[i].id!);
          } catch (_) {}
        }
      } else {
        // Buat file baru di appDataFolder
        final newDriveFile = drive.File()
          ..name = _backupFileName
          ..parents = ['appDataFolder'];

        uploadedFile = await driveApi.files.create(
          newDriveFile,
          uploadMedia: uploadMedia,
          $fields: 'id, name, modifiedTime',
        );
      }

      await _recordSyncTime(remoteModified: uploadedFile.modifiedTime);
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
  Future<bool> restoreFromDrive({bool interactive = true}) async {
    try {
      final isOnline = await hasInternetConnection();
      if (!isOnline) {
        throw Exception('Tidak ada koneksi internet.');
      }

      final driveApi = await _getDriveApi(interactive: interactive);
      if (driveApi == null) {
        throw Exception('Belum login ke akun Google.');
      }

      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName' and trashed = false",
        orderBy: 'modifiedTime desc',
        $fields: 'files(id, name, modifiedTime)',
      );

      final files = fileList.files;
      if (files == null || files.isEmpty) {
        throw Exception('Tidak ditemukan file cadangan di Google Drive.');
      }

      final file = files.first;
      final fileId = file.id!;

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

      await _recordSyncTime(remoteModified: file.modifiedTime);
      _dataUpdatedController.add(null);
      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Sinkronisasi dua arah yang cerdas antara HP lokal dan Google Drive:
  /// 1. Jika HP lokal kosong dan cloud ada data -> otomatis pulihkan dari Google Drive.
  /// 2. Jika cloud memiliki perubahan lebih baru dan HP lokal tidak ada perubahan offline -> pulihkan dari cloud.
  /// 3. Jika cloud dan HP lokal sama-sama memiliki perubahan baru -> lakukan Smart Merge (gabungkan keduanya).
  /// 4. Jika HP lokal memiliki perubahan dan cloud belum diperbarui -> unggah ke Google Drive.
  Future<bool> syncWithDrive({bool interactive = false}) async {
    try {
      final isOnline = await hasInternetConnection();
      if (!isOnline) {
        if (interactive) throw Exception('Tidak ada koneksi internet.');
        return false;
      }

      final driveApi = await _getDriveApi(interactive: interactive);
      if (driveApi == null) {
        if (interactive) throw Exception('Belum login ke akun Google.');
        return false;
      }

      final remote = await checkRemoteBackup(interactive: interactive);
      final isLocalEmpty = await DatabaseHelper.instance.isDatabaseEmpty();
      final localTxCount = await DatabaseHelper.instance.getTransactionCount();
      final hasPending = await hasPendingChanges();

      final prefs = await SharedPreferences.getInstance();
      final lastRemoteModifiedEpoch = prefs.getInt(_prefKeyLastRemoteModified);
      final lastRemoteModified = lastRemoteModifiedEpoch != null
          ? DateTime.fromMillisecondsSinceEpoch(lastRemoteModifiedEpoch)
          : null;

      // Kasus 1: Di cloud belum ada cadangan sama sekali
      if (!remote.exists) {
        if (!isLocalEmpty || localTxCount > 0) {
          return await backupToDrive(force: true, interactive: interactive);
        }
        return true;
      }

      // Kasus 2: Di cloud ada cadangan, tapi database lokal masih kosong (HP baru / fresh install)
      if (isLocalEmpty || localTxCount == 0) {
        final restored = await restoreFromDrive(interactive: interactive);
        return restored;
      }

      // Kasus 3: Bandingkan modifiedTime remote dengan yang terakhir tersinkron di HP ini
      final isRemoteNewer = remote.modifiedTime != null &&
          (lastRemoteModified == null ||
              remote.modifiedTime!.isAfter(lastRemoteModified.add(const Duration(seconds: 2))));

      if (isRemoteNewer) {
        if (!hasPending) {
          // Cloud diperbarui dari HP lain dan HP ini tidak memiliki transaksi tertunda -> unduh langsung
          final restored = await restoreFromDrive(interactive: interactive);
          return restored;
        } else {
          // Keduanya punya transaksi baru -> Smart Merge!
          return await _mergeAndSyncWithDrive(driveApi, remote.fileId!, interactive: interactive);
        }
      } else {
        if (hasPending) {
          // HP ini punya perubahan baru yang belum terunggah -> unggah
          return await backupToDrive(force: true, interactive: interactive);
        } else {
          // Sudah identik
          await _recordSyncTime(remoteModified: remote.modifiedTime);
          return true;
        }
      }
    } catch (e) {
      if (interactive) rethrow;
      return false;
    }
  }

  Future<bool> _mergeAndSyncWithDrive(
    drive.DriveApi driveApi,
    String fileId, {
    bool interactive = false,
  }) async {
    final dbPath = await DatabaseHelper.instance.getDatabaseFilePath();
    final tempPath = join(dirname(dbPath), 'temp_remote_merge.db');
    final tempFile = File(tempPath);

    try {
      final driveMedia = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      List<int> downloadedBytes = [];
      await for (final chunk in driveMedia.stream) {
        downloadedBytes.addAll(chunk);
      }

      if (downloadedBytes.isNotEmpty) {
        await tempFile.writeAsBytes(downloadedBytes, flush: true);
        await DatabaseHelper.instance.mergeExternalDatabase(tempPath);
        _dataUpdatedController.add(null);
      }

      // Setelah merge selesai, unggah database gabungan ke Google Drive
      return await backupToDrive(force: true, interactive: interactive);
    } finally {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
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
      // Debounce 2.5 detik agar aksi beruntun (misal tambah transaksi berturut-turut) digabung menjadi 1 kali sync
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
      final isLogged = await GoogleAuthService.instance.isLoggedIn();
      if (!isLogged) return;

      // 2. Cek koneksi internet
      final isOnline = await hasInternetConnection();
      if (!isOnline) {
        // Tetap tandai ada pending changes jika tadi offline
        return;
      }

      // 3. Beritahu UI bahwa sinkronisasi sedang berjalan
      _currentProgress = SyncProgress.syncing;
      _syncProgressController.add(SyncProgress.syncing);

      final success = await syncWithDrive(interactive: false);
      if (success) {
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
