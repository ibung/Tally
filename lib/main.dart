import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tally/app.dart';
import 'package:tally/core/database/database_helper.dart';
import 'package:tally/core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);

  // Set system UI: status bar dark icons, nav bar putih tanpa abu-abu (contrast scrim disabled)
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUiStyle);

  // Initialize database
  await DatabaseHelper.instance.database;

  runApp(
    const ProviderScope(
      child: TallyApp(),
    ),
  );
}
