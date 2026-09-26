import 'package:flutter/material.dart';

import 'app.dart';
import 'app_scope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initSupabase();
  } catch (e) {
    // Never block the app (auto-vibrate, qibla, calendar work offline).
    debugPrint('Supabase init failed: $e');
  }
  runApp(AppScope(child: const GpsApp()));
}
