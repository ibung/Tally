import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tally/core/router/app_router.dart';
import 'package:tally/core/theme/app_theme.dart';
import 'package:tally/core/theme/theme_provider.dart';
import 'package:tally/core/services/drive_sync_service.dart';

class TallyApp extends ConsumerStatefulWidget {
  const TallyApp({super.key});

  @override
  ConsumerState<TallyApp> createState() => _TallyAppState();
}

class _TallyAppState extends ConsumerState<TallyApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        DriveSyncService.instance.triggerBackgroundSync(immediate: true, isDataChange: false);
      },
      onHide: () {
        DriveSyncService.instance.triggerBackgroundSync(immediate: true, isDataChange: false);
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Tally',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
