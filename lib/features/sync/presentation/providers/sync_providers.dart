import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/google_auth_service.dart';
import '../../../../core/services/drive_sync_service.dart';
import '../../../wallets/presentation/providers/wallet_providers.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../budgets/presentation/providers/budget_providers.dart';

class SyncState {
  final bool isSyncing;
  final bool isChecking;
  final DateTime? lastSyncTime;
  final BackupInfo? remoteBackup;
  final int localTxCount;
  final String? message;
  final String? error;

  const SyncState({
    this.isSyncing = false,
    this.isChecking = false,
    this.lastSyncTime,
    this.remoteBackup,
    this.localTxCount = 0,
    this.message,
    this.error,
  });

  SyncState copyWith({
    bool? isSyncing,
    bool? isChecking,
    DateTime? lastSyncTime,
    BackupInfo? remoteBackup,
    int? localTxCount,
    String? message,
    String? error,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      isChecking: isChecking ?? this.isChecking,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      remoteBackup: remoteBackup ?? this.remoteBackup,
      localTxCount: localTxCount ?? this.localTxCount,
      message: message,
      error: error,
    );
  }
}

final googleUserProvider = StreamProvider<GoogleSignInAccount?>((ref) {
  return GoogleAuthService.instance.authStateChanges;
});

final cachedGoogleUserProvider = FutureProvider<Map<String, String?>?>((ref) async {
  return GoogleAuthService.instance.getCachedUserData();
});

class ConnectivityNotifier extends StateNotifier<bool> {
  Timer? _timer;

  ConnectivityNotifier() : super(true) {
    final isTesting = Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTesting) {
      checkConnection();
      _timer = Timer.periodic(const Duration(seconds: 8), (_) => checkConnection());
    }
  }

  Future<bool> checkConnection() async {
    final online = await DriveSyncService.instance.hasInternetConnection();
    if (mounted && state != online) {
      state = online;
    }
    return online;
  }

  void setOnline(bool value) {
    if (mounted && state != value) {
      state = value;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final isOnlineProvider = StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
  return ConnectivityNotifier();
});

class SyncNotifier extends StateNotifier<SyncState> {
  final Ref ref;
  StreamSubscription<SyncProgress>? _progressSub;

  SyncNotifier(this.ref) : super(const SyncState()) {
    _init();
    _subscribeProgress();
  }

  void _subscribeProgress() {
    _progressSub = DriveSyncService.instance.syncProgressStream.listen((progress) async {
      if (!mounted) return;
      if (progress == SyncProgress.syncing) {
        state = state.copyWith(isSyncing: true);
      } else if (progress == SyncProgress.success) {
        final lastTime = await DriveSyncService.instance.getLastSyncTime();
        final txCount = await DatabaseHelper.instance.getTransactionCount();
        state = state.copyWith(
          isSyncing: false,
          lastSyncTime: lastTime,
          localTxCount: txCount,
        );
        await checkRemoteBackup();
      } else {
        if (state.isSyncing) {
          state = state.copyWith(isSyncing: false);
        }
      }
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final lastTime = await DriveSyncService.instance.getLastSyncTime();
    final txCount = await DatabaseHelper.instance.getTransactionCount();
    state = state.copyWith(lastSyncTime: lastTime, localTxCount: txCount);
    if (await GoogleAuthService.instance.isLoggedIn()) {
      await checkRemoteBackup();
    }
  }

  String _formatErrorMessage(dynamic error, String action) {
    final msg = error.toString();
    if (msg.contains('SocketException') ||
        msg.contains('Failed host lookup') ||
        msg.contains('ClientException') ||
        msg.contains('NetworkImage') ||
        msg.contains('HandshakeException') ||
        msg.contains('TimeoutException') ||
        msg.contains('tidak ada internet') ||
        msg.contains('No address associated with hostname')) {
      ref.read(isOnlineProvider.notifier).setOnline(false);
      return 'Tidak ada koneksi internet. Data lokal Anda aman di HP dan akan otomatis dicadangkan saat online.';
    }
    if (msg.contains('Belum login')) {
      return 'Silakan hubungkan akun Google Anda terlebih dahulu.';
    }
    if (msg.contains('File cadangan di Google Drive kosong')) {
      return 'File cadangan di Google Drive kosong atau belum tersedia.';
    }
    final cleaned = msg.replaceFirst(RegExp(r'^Exception:\s*'), '');
    return 'Gagal $action: $cleaned';
  }

  Future<void> checkRemoteBackup() async {
    state = state.copyWith(isChecking: true, error: null);
    try {
      final isOnline = await DriveSyncService.instance.hasInternetConnection();
      ref.read(isOnlineProvider.notifier).setOnline(isOnline);
      if (!isOnline) {
        final txCount = await DatabaseHelper.instance.getTransactionCount();
        state = state.copyWith(isChecking: false, localTxCount: txCount);
        return;
      }
      final info = await DriveSyncService.instance.checkRemoteBackup();
      final txCount = await DatabaseHelper.instance.getTransactionCount();
      state = state.copyWith(isChecking: false, remoteBackup: info, localTxCount: txCount);
    } catch (_) {
      state = state.copyWith(isChecking: false);
    }
  }

  Future<bool> signIn() async {
    state = state.copyWith(isSyncing: true, error: null, message: 'Menghubungkan akun Google...');
    try {
      final user = await GoogleAuthService.instance.signIn();
      if (user != null) {
        state = state.copyWith(isSyncing: true, message: 'Berhasil login: ${user.email}. Memeriksa cadangan...');
        
        final remote = await DriveSyncService.instance.checkRemoteBackup();
        final isLocalEmpty = await DatabaseHelper.instance.isDatabaseEmpty();
        final txCount = await DatabaseHelper.instance.getTransactionCount();

        state = state.copyWith(remoteBackup: remote, localTxCount: txCount);

        // Jika ada cadangan di cloud dan database lokal saat ini KOSONG (misal install ulang / ganti HP),
        // OTOMATIS pulihkan data dari Google Drive!
        if (remote.exists && isLocalEmpty) {
          state = state.copyWith(
            message: 'Ditemukan data cadangan di Google Drive. Memulihkan data Anda...',
          );
          await restoreNow();
        } else if (!remote.exists && !isLocalEmpty) {
          // Jika di cloud belum ada cadangan dan lokal ada data, otomatis cadangkan
          await backupNow();
        } else {
          state = state.copyWith(
            isSyncing: false,
            message: 'Berhasil login: ${user.email}',
          );
        }
        ref.invalidate(cachedGoogleUserProvider);
        return true;
      } else {
        state = state.copyWith(isSyncing: false, error: 'Login dibatalkan.');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isSyncing: false, error: _formatErrorMessage(e, 'login'));
      return false;
    }
  }

  Future<void> signOut() async {
    await GoogleAuthService.instance.signOut();
    ref.invalidate(cachedGoogleUserProvider);
    final txCount = await DatabaseHelper.instance.getTransactionCount();
    state = SyncState(localTxCount: txCount);
  }

  Future<bool> backupNow({bool force = false}) async {
    state = state.copyWith(isSyncing: true, error: null, message: 'Mengunggah cadangan ke Google Drive...');
    try {
      final isOnline = await DriveSyncService.instance.hasInternetConnection();
      ref.read(isOnlineProvider.notifier).setOnline(isOnline);
      if (!isOnline) {
        state = state.copyWith(
          isSyncing: false,
          error: 'Tidak ada koneksi internet. Data lokal Anda aman di HP dan akan otomatis dicadangkan saat online.',
        );
        return false;
      }

      final isLocalEmpty = await DatabaseHelper.instance.isDatabaseEmpty();
      if (isLocalEmpty && !force) {
        final remote = await DriveSyncService.instance.checkRemoteBackup();
        if (remote.exists) {
          state = state.copyWith(
            isSyncing: false,
            error: 'Data di HP ini masih kosong! Pencadangan dibatalkan agar tidak menimpa cadangan di Google Drive. Silakan pilih "Pulihkan Data".',
          );
          return false;
        }
      }

      final success = await DriveSyncService.instance.backupToDrive(force: force, interactive: true);
      final lastTime = await DriveSyncService.instance.getLastSyncTime();
      final txCount = await DatabaseHelper.instance.getTransactionCount();
      state = state.copyWith(
        isSyncing: false,
        lastSyncTime: lastTime,
        localTxCount: txCount,
        message: 'Cadangan berhasil disimpan ke Google Drive!',
      );
      await checkRemoteBackup();
      return success;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: _formatErrorMessage(e, 'mencadangkan'),
      );
      return false;
    }
  }

  Future<bool> restoreNow() async {
    state = state.copyWith(isSyncing: true, error: null, message: 'Mengunduh dan memulihkan data dari Google Drive...');
    try {
      final isOnline = await DriveSyncService.instance.hasInternetConnection();
      ref.read(isOnlineProvider.notifier).setOnline(isOnline);
      if (!isOnline) {
        state = state.copyWith(
          isSyncing: false,
          error: 'Tidak ada koneksi internet. Silakan hubungkan HP ke internet untuk memulihkan cadangan dari Google Drive.',
        );
        return false;
      }

      final success = await DriveSyncService.instance.restoreFromDrive(interactive: true);
      final lastTime = await DriveSyncService.instance.getLastSyncTime();

      // Trigger counter transaksi & invalidate seluruh provider lokal agar UI langsung merefleksikan data pulih
      ref.read(transactionsVersionProvider.notifier).state++;
      ref.invalidate(walletsProvider);
      ref.invalidate(totalActiveBalanceProvider);
      ref.invalidate(categoriesProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(budgetsProvider);
      ref.invalidate(dailySummaryProvider);
      ref.invalidate(historicalEndBalanceProvider);

      final txCount = await DatabaseHelper.instance.getTransactionCount();

      state = state.copyWith(
        isSyncing: false,
        lastSyncTime: lastTime,
        localTxCount: txCount,
        message: txCount > 0
            ? 'Data berhasil dipulihkan ($txCount transaksi dimuat)!'
            : 'Sinkronisasi selesai (0 transaksi di cadangan).',
      );
      await checkRemoteBackup();
      return success;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: _formatErrorMessage(e, 'memulihkan'),
      );
      return false;
    }
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(ref);
});
