import 'package:flutter/material.dart';

import 'app.dart';
import 'app_scope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(AppScope(child: const GpsApp()));
}
