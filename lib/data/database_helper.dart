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
      version: 9,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE pharmacies ADD COLUMN category TEXT;');
    }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS salesmen (
          name TEXT PRIMARY KEY COLLATE NOCASE,
          phone_number TEXT
        );
      ''');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pharmacies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        party_code TEXT UNIQUE,
        name TEXT,
        salesman TEXT,
        city TEXT,
        total_amount REAL,
        bucket_121_180 REAL,
        bucket_181_270 REAL,
        bucket_271_360 REAL,
        last_import_date TEXT,
        notes TEXT,
        created_at TEXT,
        category TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pharmacy_id INTEGER,
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

    await db.execute('''
      CREATE TABLE salesmen (
        name TEXT PRIMARY KEY COLLATE NOCASE,
        phone_number TEXT
      );
    ''');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}
