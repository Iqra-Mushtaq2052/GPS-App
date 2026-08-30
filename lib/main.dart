import 'package:flutter/material.dart';

import 'app.dart';
import 'app_scope.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AppScope(child: const GpsApp()));
}
