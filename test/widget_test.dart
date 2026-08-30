import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gps_app/app.dart';
import 'package:gps_app/app_scope.dart';
import 'package:gps_app/data/db/app_database.dart';

void main() {
  testWidgets('App boots and shows a loading indicator while permissions are checked',
      (WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(AppScope(database: db, child: const GpsApp()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
