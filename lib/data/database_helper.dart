import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pharmacy_dues_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pharmacies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        party_code TEXT UNIQUE,
        name TEXT,
        salesman TEXT,
        city TEXT,
        created_at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pharmacy_id INTEGER REFERENCES pharmacies(id),
        invoice_number TEXT,
        invoice_date TEXT,
        amount REAL,
        due_amount REAL,
        due_date TEXT,
        status TEXT CHECK(status IN ('open','paid')),
        paid_date TEXT,
        created_at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pharmacy_id INTEGER REFERENCES pharmacies(id),
        reminder_type TEXT CHECK(reminder_type IN ('pharmacy','salesman')),
        salesman_name TEXT,
        scheduled_date TEXT,
        scheduled_time TEXT,
        status TEXT CHECK(status IN ('pending','done','rescheduled')),
        notification_id INTEGER,
        notes TEXT,
        created_at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE city_aliases (
        raw_value TEXT PRIMARY KEY COLLATE NOCASE,
        canonical_city TEXT,
        created_at TEXT
      );
    ''');
  }

  Future<void> _safeAlterTable(Database db, String query) async {
    try {
      await db.execute(query);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('duplicate column name') || msg.contains('already exists') || msg.contains('duplicate')) {
        // Silently ignore
      } else {
        rethrow;
      }
    }
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _safeAlterTable(db, 'ALTER TABLE reminders ADD COLUMN scheduled_time TEXT;');
    }
    if (oldVersion < 3) {
      await _safeAlterTable(db, 'ALTER TABLE pharmacies ADD COLUMN salesman TEXT;');
    }
    if (oldVersion < 4) {
      await _safeAlterTable(db, "ALTER TABLE reminders ADD COLUMN reminder_type TEXT CHECK(reminder_type IN ('pharmacy','salesman'));");
      await _safeAlterTable(db, "ALTER TABLE reminders ADD COLUMN salesman_name TEXT;");
      try {
        await db.execute("UPDATE reminders SET reminder_type = 'pharmacy';");
      } catch (_) {}
    }
    if (oldVersion < 5) {
      await _safeAlterTable(db, 'ALTER TABLE pharmacies ADD COLUMN city TEXT;');
    }
    if (oldVersion < 6) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS city_aliases (
            raw_value TEXT PRIMARY KEY COLLATE NOCASE,
            canonical_city TEXT,
            created_at TEXT
          );
        ''');
      } catch (_) {}
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}
