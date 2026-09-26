import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gps_app/app.dart';
import 'package:gps_app/app_scope.dart';
import 'package:gps_app/core/supabase/supabase_service.dart';
import 'package:gps_app/data/db/app_database.dart';
import 'package:gps_app/features/role/role_selection_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('First launch boots into role selection',
      (WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(AppScope(database: db, child: const GpsApp()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(RoleSelectionPage), findsOneWidget);
  });

  test('CloudPrayerTimes parses HH:mm into today', () {
    final t = CloudPrayerTimes.fromJson({
      'mosque_id': 'm1',
      'fajr': '05:10',
      'dhuhr': '13:30',
      'asr': '17:00',
      'maghrib': '18:45',
      'isha': '20:15',
      'jumuah': '13:45',
      'updated_at': '2026-09-26T10:00:00Z',
    });
    final today = t.toTodayDateTimes();
    expect(today['Fajr']!.hour, 5);
    expect(today['Fajr']!.minute, 10);
    expect(today['Isha']!.hour, 20);
    expect(t.jumuah, '13:45');
  });

  test('friendlyCloudError maps server codes', () {
    expect(friendlyCloudError(Exception('DUPLICATE_MOSQUE')), contains('50 meter'));
    expect(friendlyCloudError(Exception('IMAM_NOT_APPROVED')), contains('approve'));
  });
}
