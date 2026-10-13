import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  final String? message;
  final String? error;

  const SyncState({
    this.isSyncing = false,
    this.isChecking = false,
    this.lastSyncTime,
    this.remoteBackup,
    this.message,
    this.error,
  });

  SyncState copyWith({
    bool? isSyncing,
    bool? isChecking,
    DateTime? lastSyncTime,
    BackupInfo? remoteBackup,
    String? message,
    String? error,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      isChecking: isChecking ?? this.isChecking,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      remoteBackup: remoteBackup ?? this.remoteBackup,
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

class SyncNotifier extends StateNotifier<SyncState> {
  final Ref ref;

  SyncNotifier(this.ref) : super(const SyncState()) {
    _init();
  }

  Future<void> _init() async {
    final lastTime = await DriveSyncService.instance.getLastSyncTime();
    state = state.copyWith(lastSyncTime: lastTime);
    if (GoogleAuthService.instance.currentUser != null) {
      await checkRemoteBackup();
    }
  }

  Future<void> checkRemoteBackup() async {
    state = state.copyWith(isChecking: true, error: null);
    try {
      final info = await DriveSyncService.instance.checkRemoteBackup();
      state = state.copyWith(isChecking: false, remoteBackup: info);
    } catch (e) {
      state = state.copyWith(isChecking: false, error: e.toString());
    }
  }

  Future<bool> signIn() async {
    state = state.copyWith(isSyncing: true, error: null, message: 'Menghubungkan akun Google...');
    try {
      final user = await GoogleAuthService.instance.signIn();
      if (user != null) {
        state = state.copyWith(isSyncing: false, message: 'Berhasil login: ${user.email}');
        await checkRemoteBackup();
        return true;
      } else {
        state = state.copyWith(isSyncing: false, error: 'Login dibatalkan.');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isSyncing: false, error: 'Gagal login: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await GoogleAuthService.instance.signOut();
    state = const SyncState();
  }

  Future<bool> backupNow() async {
    state = state.copyWith(isSyncing: true, error: null, message: 'Mengunggah cadangan ke Google Drive...');
    try {
      final success = await DriveSyncService.instance.backupToDrive();
      final lastTime = await DriveSyncService.instance.getLastSyncTime();
      state = state.copyWith(
        isSyncing: false,
        lastSyncTime: lastTime,
        message: 'Cadangan berhasil disimpan ke Google Drive!',
      );
      await checkRemoteBackup();
      return success;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: 'Gagal mencadangkan: $e',
      );
      return false;
    }
  }

  Future<bool> restoreNow() async {
    state = state.copyWith(isSyncing: true, error: null, message: 'Mengunduh dan memulihkan data dari Google Drive...');
    try {
      final success = await DriveSyncService.instance.restoreFromDrive();
      final lastTime = await DriveSyncService.instance.getLastSyncTime();

      // Invalidate semua provider lokal agar UI langsung merefleksikan data pulih
      ref.invalidate(walletsProvider);
      ref.invalidate(totalActiveBalanceProvider);
      ref.invalidate(categoriesProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(budgetsProvider);

      state = state.copyWith(
        isSyncing: false,
        lastSyncTime: lastTime,
        message: 'Data berhasil dipulihkan dari Google Drive!',
      );
      return success;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: 'Gagal memulihkan: $e',
      );
      return false;
    }
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(ref);
});
