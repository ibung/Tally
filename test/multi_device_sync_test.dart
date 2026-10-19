import 'package:flutter_test/flutter_test.dart';
import 'package:tally/core/services/drive_sync_service.dart';
import 'package:tally/features/sync/presentation/providers/sync_providers.dart';

void main() {
  group('Multi-Device Sync & BackupInfo Tests', () {
    test('BackupInfo reports correct existence and metadata', () {
      final now = DateTime(2026, 10, 19, 10, 0);
      final info = BackupInfo(
        exists: true,
        fileId: 'drive_file_123',
        modifiedTime: now,
        sizeBytes: 15360,
      );

      expect(info.exists, isTrue);
      expect(info.fileId, 'drive_file_123');
      expect(info.modifiedTime, now);
      expect(info.sizeBytes, 15360);
    });

    test('SyncState accurately models multi-device state', () {
      const state = SyncState(
        isSyncing: false,
        isChecking: false,
        localTxCount: 5,
        message: 'Data berhasil disinkronkan',
      );

      expect(state.isSyncing, isFalse);
      expect(state.localTxCount, 5);
      expect(state.message, 'Data berhasil disinkronkan');

      final syncingState = state.copyWith(isSyncing: true, message: 'Menyinkronkan data...');
      expect(syncingState.isSyncing, isTrue);
      expect(syncingState.message, 'Menyinkronkan data...');
    });

    test('SyncProgress enum covers all sync lifecycle states', () {
      expect(SyncProgress.values, contains(SyncProgress.idle));
      expect(SyncProgress.values, contains(SyncProgress.syncing));
      expect(SyncProgress.values, contains(SyncProgress.success));
      expect(SyncProgress.values, contains(SyncProgress.error));
    });

    test('SyncState remote backup detection handles empty vs populated remote', () {
      const emptyRemote = BackupInfo(exists: false);
      const populatedRemote = BackupInfo(
        exists: true,
        fileId: 'remote-1',
        sizeBytes: 4096,
      );

      const stateEmpty = SyncState(remoteBackup: emptyRemote, localTxCount: 0);
      expect(stateEmpty.remoteBackup?.exists, isFalse);

      const stateWithRemote = SyncState(remoteBackup: populatedRemote, localTxCount: 0);
      expect(stateWithRemote.remoteBackup?.exists, isTrue);
      expect(stateWithRemote.localTxCount, 0);
    });
  });
}
