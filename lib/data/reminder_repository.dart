import '../models/reminder.dart';
import 'database_helper.dart';

class ReminderRepository {
  Future<int> create(Reminder reminder) async {
    assert(
      (reminder.pharmacyId != null && reminder.salesmanName == null && reminder.reminderType == 'pharmacy') ||
      (reminder.pharmacyId == null && reminder.salesmanName != null && reminder.reminderType == 'salesman'),
      'Reminder must be either pharmacy-based or salesman-based, never both.'
    );
    final db = await DatabaseHelper.instance.database;
    final map = reminder.toMap();
    map.remove('id'); // Ensure SQLite assigns a fresh auto-increment ID
    return await db.insert('reminders', map);
  }

  Future<List<Reminder>> getByPharmacy(int pharmacyId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'reminders',
      where: 'pharmacy_id = ?',
      whereArgs: [pharmacyId],
      orderBy: 'scheduled_date DESC',
    );
    return maps.map((map) => Reminder.fromMap(map)).toList();
  }

  Future<List<Reminder>> getBySalesman(String salesmanName) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'reminders',
      where: 'reminder_type = ? AND TRIM(salesman_name) = ? COLLATE NOCASE',
      whereArgs: ['salesman', salesmanName.trim()],
      orderBy: 'scheduled_date DESC, scheduled_time DESC, id DESC',
    );
    return maps.map((map) => Reminder.fromMap(map)).toList();
  }

  Future<List<Reminder>> getScheduledOn(String date) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'reminders',
      where: 'scheduled_date = ? AND status = ?',
      whereArgs: [date, 'pending'],
    );
    return maps.map((map) => Reminder.fromMap(map)).toList();
  }

  Future<void> markDone(int reminderId, {String? notes}) async {
    final db = await DatabaseHelper.instance.database;
    final Map<String, Object?> values = {'status': 'done'};
    if (notes != null) {
      values['notes'] = notes;
    }
    await db.update(
      'reminders',
      values,
      where: 'id = ?',
      whereArgs: [reminderId],
    );
  }

  Future<void> markRescheduled(int reminderId, {String? notes}) async {
    final db = await DatabaseHelper.instance.database;
    final Map<String, Object?> values = {'status': 'rescheduled'};
    if (notes != null) {
      values['notes'] = notes;
    }
    await db.update(
      'reminders',
      values,
      where: 'id = ?',
      whereArgs: [reminderId],
    );
  }

  Future<void> updateNotes(int reminderId, String notes) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'reminders',
      {'notes': notes},
      where: 'id = ?',
      whereArgs: [reminderId],
    );
  }

  Future<List<Reminder>> getAllPending() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'reminders',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'scheduled_date ASC, scheduled_time ASC',
    );
    return maps.map((map) => Reminder.fromMap(map)).toList();
  }

  Future<Reminder?> getNextPendingReminder(int pharmacyId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'reminders',
      where: 'pharmacy_id = ? AND status = ?',
      whereArgs: [pharmacyId, 'pending'],
      orderBy: 'scheduled_date ASC, scheduled_time ASC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Reminder.fromMap(maps.first);
  }

  Future<Reminder?> getNextPendingReminderForSalesman(String salesmanName) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'reminders',
      where: 'reminder_type = ? AND TRIM(salesman_name) = ? COLLATE NOCASE AND status = ?',
      whereArgs: ['salesman', salesmanName.trim(), 'pending'],
      orderBy: 'scheduled_date ASC, scheduled_time ASC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Reminder.fromMap(maps.first);
  }

  Future<Reminder?> getById(int id) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Reminder.fromMap(maps.first);
  }

  Future<void> updateNotificationId(int reminderId, int notificationId) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'reminders',
      {'notification_id': notificationId},
      where: 'id = ?',
      whereArgs: [reminderId],
    );
  }
}
