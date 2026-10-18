import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/services/google_auth_service.dart';
import '../providers/sync_providers.dart';

class SyncAccountSheet extends ConsumerWidget {
  const SyncAccountSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SyncAccountSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    final syncNotifier = ref.read(syncProvider.notifier);
    final currentUser = GoogleAuthService.instance.currentUser;
    final cachedUserAsync = ref.watch(cachedGoogleUserProvider);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: bottomInset + 24,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Title
            Row(
              children: [
                Icon(Icons.cloud_sync_rounded, size: 24, color: AppTheme.textPrimary(context)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cadangan & Sinkronisasi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  color: AppTheme.textSecondary(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status message / notice
            if (syncState.message != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.subtleBg(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 18, color: AppTheme.textPrimary(context)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        syncState.message!,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimary(context)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (syncState.error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.subtleBg(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.error(context).withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 18, color: AppTheme.error(context)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        syncState.error!,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.error(context)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Content: Logged in vs Not logged in
            if (currentUser != null || (cachedUserAsync.valueOrNull?['email'] != null)) ...[
              _buildLoggedInSection(
                context,
                currentUser: currentUser,
                cachedUser: cachedUserAsync.valueOrNull,
                syncState: syncState,
                syncNotifier: syncNotifier,
              ),
            ] else ...[
              _buildLoggedOutSection(
                context,
                syncState: syncState,
                syncNotifier: syncNotifier,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoggedOutSection(
    BuildContext context, {
    required SyncState syncState,
    required SyncNotifier syncNotifier,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.subtleBg(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Amankan Data Anda ke Google Drive',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hubungkan akun Google (Gmail) agar seluruh transaksi, dompet, dan kuota dicadangkan secara otomatis. Jika aplikasi terhapus atau Anda ganti perangkat, data dapat dipulihkan kapan saja.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary(context),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              _buildFeatureItem(context, Icons.lock_outline_rounded, 'Tersimpan di brankas tersembunyi Google Drive Anda'),
              const SizedBox(height: 6),
              _buildFeatureItem(context, Icons.bolt_rounded, 'Aplikasi tetap 100% cepat & berfungsi saat offline'),
              const SizedBox(height: 6),
              _buildFeatureItem(context, Icons.phonelink_setup_rounded, 'Pulihkan instan saat install ulang atau ganti HP'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: syncState.isSyncing
              ? null
              : () async {
                  await syncNotifier.signIn();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryButtonBg(context),
            foregroundColor: AppTheme.primaryButtonText(context),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: syncState.isSyncing
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppTheme.primaryButtonText(context)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('Menghubungkan Akun...'),
                  ],
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.login_rounded, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Masuk dengan Akun Google',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildLoggedInSection(
    BuildContext context, {
    required dynamic currentUser,
    required Map<String, String?>? cachedUser,
    required SyncState syncState,
    required SyncNotifier syncNotifier,
  }) {
    final email = currentUser?.email ?? cachedUser?['email'] ?? 'Akun Google';
    final name = currentUser?.displayName ?? cachedUser?['name'] ?? 'Pengguna';
    final photoUrl = currentUser?.photoUrl ?? cachedUser?['photo'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Account Profile Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.subtleBg(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.borderStrong(context),
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'G',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryButtonText(context)),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('Aktif', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary(context))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Backup Status Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.subtleBg(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Data di HP ini', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context))),
                  Text(
                    '${syncState.localTxCount} transaksi',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary(context)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Cadangan di Google Drive', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context))),
                  Text(
                    syncState.remoteBackup?.exists == true
                        ? 'Tersedia (${syncState.remoteBackup?.sizeBytes != null ? (syncState.remoteBackup!.sizeBytes! / 1024).toStringAsFixed(1) : '0'} KB)'
                        : (syncState.isChecking ? 'Memeriksa...' : 'Belum ada'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: syncState.remoteBackup?.exists == true ? Colors.green : AppTheme.textPrimary(context),
                    ),
                  ),
                ],
              ),
              if (syncState.lastSyncTime != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sinkronisasi Terakhir', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context))),
                    Text(
                      '${DateFormatter.formatDate(syncState.lastSyncTime!)} ${DateFormatter.formatTime(syncState.lastSyncTime!)}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary(context)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Sinkronisasi Otomatis', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context))),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Aktif di Latar Belakang',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        if (syncState.remoteBackup?.exists == true && syncState.localTxCount == 0) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 20, color: Colors.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Data Anda ditemukan di Google Drive! Silakan tekan tombol "Pulihkan Data" di bawah untuk memuat kembali semua transaksi dan dompet Anda.',
                    style: TextStyle(fontSize: 12, height: 1.4, color: AppTheme.textPrimary(context)),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Action Buttons: Prioritas dinamis (Pulihkan jika HP kosong tapi cloud ada data)
        if (syncState.remoteBackup?.exists == true && syncState.localTxCount == 0) ...[
          // Prioritas 1: Pulihkan
          ElevatedButton(
            onPressed: syncState.isSyncing
                ? null
                : () => _showRestoreConfirmation(context, syncNotifier, syncState.localTxCount),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryButtonBg(context),
              foregroundColor: AppTheme.primaryButtonText(context),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: syncState.isSyncing
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppTheme.primaryButtonText(context)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Memproses Sinkronisasi...'),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restore_rounded, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Pulihkan Data dari Google Drive',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: syncState.isSyncing
                ? null
                : () async {
                    await syncNotifier.backupNow();
                  },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary(context),
              side: BorderSide(color: AppTheme.borderStrong(context)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.backup_rounded, size: 20),
                SizedBox(width: 10),
                Text(
                  'Cadangkan Sekarang',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ] else ...[
          // Prioritas 1: Cadangkan
          ElevatedButton(
            onPressed: syncState.isSyncing
                ? null
                : () async {
                    await syncNotifier.backupNow();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryButtonBg(context),
              foregroundColor: AppTheme.primaryButtonText(context),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: syncState.isSyncing
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppTheme.primaryButtonText(context)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Menyinkronkan...'),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.backup_rounded, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Cadangkan Sekarang',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: syncState.isSyncing
                ? null
                : () => _showRestoreConfirmation(context, syncNotifier, syncState.localTxCount),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary(context),
              side: BorderSide(color: AppTheme.borderStrong(context)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restore_rounded, size: 20),
                SizedBox(width: 10),
                Text(
                  'Pulihkan Data dari Cloud',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),

        // Sign Out Button
        Center(
          child: TextButton.icon(
            onPressed: () async {
              await syncNotifier.signOut();
            },
            icon: Icon(Icons.logout_rounded, size: 16, color: AppTheme.error(context)),
            label: Text(
              'Keluar dari Akun Google',
              style: TextStyle(fontSize: 13, color: AppTheme.error(context)),
            ),
          ),
        ),
      ],
    );
  }

  void _showRestoreConfirmation(BuildContext context, SyncNotifier syncNotifier, int localTxCount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Pulihkan Data?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context)),
        ),
        content: Text(
          localTxCount == 0
              ? 'Data cadangan dari Google Drive Anda akan diunduh dan dipulihkan ke HP ini.'
              : 'Data saat ini ($localTxCount transaksi) akan digantikan dengan data cadangan dari Google Drive Anda. Lanjutkan?',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary(context), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Batal', style: TextStyle(color: AppTheme.textSecondary(context))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await syncNotifier.restoreNow();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryButtonBg(context),
              foregroundColor: AppTheme.primaryButtonText(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ya, Pulihkan'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.textPrimary(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context), height: 1.3),
          ),
        ),
      ],
    );
  }
}
