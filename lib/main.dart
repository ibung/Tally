import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tally/app.dart';
import 'package:tally/core/database/database_helper.dart';
import 'package:tally/core/theme/app_theme.dart';
import 'package:tally/core/theme/theme_provider.dart';
import 'package:tally/core/services/google_auth_service.dart';
import 'package:tally/core/services/drive_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);

  // Initialize database
  await DatabaseHelper.instance.database;

  // Initialize Google Auth & background sync
  GoogleAuthService.instance.initialize().then((_) {
    DriveSyncService.instance.triggerBackgroundSync();
  });

  // Load saved theme mode
  ThemeMode initialThemeMode = ThemeMode.light;
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_mode');
    if (saved == 'dark') {
      initialThemeMode = ThemeMode.dark;
    } else if (saved == 'light') {
      initialThemeMode = ThemeMode.light;
    }
  } catch (_) {}

  // Set system UI sesuai theme yang disimpan
  SystemChrome.setSystemUIOverlayStyle(
    initialThemeMode == ThemeMode.dark
        ? AppTheme.darkSystemUiStyle
        : AppTheme.systemUiStyle,
  );

  runApp(
    ProviderScope(
      overrides: [
        initialThemeModeProvider.overrideWithValue(initialThemeMode),
      ],
      child: const TallyApp(),
    ),
  );
}
