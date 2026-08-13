import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_dues_tracker/models/reminder.dart';
import 'package:pharmacy_dues_tracker/services/excel_import_service.dart';

void main() {
  group('Reminder Scheduling and Time Offset Tests', () {
    test('Calculates and formats reminders for 5 mins, 50 mins, and Next Day', () {
      final now = DateTime.now();

      // 1. 5 Minutes after
      final time5Min = now.add(const Duration(minutes: 5));
      final date5MinStr = ExcelImportService.formatDateOnly(time5Min);
      final time5MinStr = '${time5Min.hour.toString().padLeft(2, '0')}:${time5Min.minute.toString().padLeft(2, '0')}';

      final rem1 = Reminder(
        reminderType: 'salesman',
        salesmanName: 'MANOJ',
        scheduledDate: date5MinStr,
        scheduledTime: time5MinStr,
        status: 'pending',
        notes: 'Follow up in 5 minutes with Manoj',
        createdAt: ExcelImportService.formatDateOnly(now),
      );

      expect(rem1.salesmanName, equals('MANOJ'));
      expect(rem1.scheduledTime, equals(time5MinStr));

      // 2. 50 Minutes after
      final time50Min = now.add(const Duration(minutes: 50));
      final date50MinStr = ExcelImportService.formatDateOnly(time50Min);
      final time50MinStr = '${time50Min.hour.toString().padLeft(2, '0')}:${time50Min.minute.toString().padLeft(2, '0')}';

      final rem2 = Reminder(
        reminderType: 'salesman',
        salesmanName: 'RAVI',
        scheduledDate: date50MinStr,
        scheduledTime: time50MinStr,
        status: 'pending',
        notes: 'Follow up in 50 minutes with Ravi',
        createdAt: ExcelImportService.formatDateOnly(now),
      );

      expect(rem2.salesmanName, equals('RAVI'));
      expect(rem2.scheduledTime, equals(time50MinStr));

      // 3. Next Day (Tomorrow at 10:00 AM)
      final nextDay = now.add(const Duration(days: 1));
      final dateNextDayStr = ExcelImportService.formatDateOnly(nextDay);
      const timeNextDayStr = '10:00';

      final rem3 = Reminder(
        reminderType: 'salesman',
        salesmanName: 'KUMAR',
        scheduledDate: dateNextDayStr,
        scheduledTime: timeNextDayStr,
        status: 'pending',
        notes: 'Follow up tomorrow morning with Kumar',
        createdAt: ExcelImportService.formatDateOnly(now),
      );

      expect(rem3.salesmanName, equals('KUMAR'));
      expect(rem3.scheduledDate, equals(dateNextDayStr));
      expect(rem3.scheduledTime, equals('10:00'));

      // Test map serialization & deserialization
      final map1 = rem1.toMap();
      final restored1 = Reminder.fromMap(map1);
      expect(restored1.salesmanName, equals('MANOJ'));
      expect(restored1.scheduledTime, equals(time5MinStr));
    });
  });
}
