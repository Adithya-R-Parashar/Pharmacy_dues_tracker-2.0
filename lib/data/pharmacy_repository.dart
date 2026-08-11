// ignore_for_file: avoid_print
import 'package:sqflite/sqflite.dart';
import '../models/pharmacy.dart';
import 'database_helper.dart';

class SalesmanSummary {
  final String salesman;
  final int pharmacyCount;
  final double totalDue;

  SalesmanSummary({
    required this.salesman,
    required this.pharmacyCount,
    required this.totalDue,
  });
}

class PharmacyRepository {
  Future<List<Pharmacy>> getAll({String sortOrder = 'DESC'}) async {
    final db = await DatabaseHelper.instance.database;
    final order = sortOrder.toUpperCase() == 'ASC' ? 'ASC' : 'DESC';
    final maps = await db.query(
      'pharmacies',
      orderBy: 'COALESCE(total_amount, 0) $order, name COLLATE NOCASE ASC',
    );
    return maps.map((map) => Pharmacy.fromMap(map)).toList();
  }

  Future<Pharmacy?> getById(int id) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'pharmacies',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Pharmacy.fromMap(maps.first);
  }

  Future<List<Pharmacy>> searchPharmacies(String query) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.rawQuery(
      'SELECT * FROM pharmacies WHERE name LIKE ? OR city LIKE ? COLLATE NOCASE ORDER BY COALESCE(total_amount, 0) DESC',
      ['%$query%', '%$query%'],
    );
    return maps.map((map) => Pharmacy.fromMap(map)).toList();
  }

  Future<Pharmacy?> getByPartyCode(String code) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'pharmacies',
      where: 'party_code = ?',
      whereArgs: [code],
    );
    if (maps.isEmpty) return null;
    return Pharmacy.fromMap(maps.first);
  }

  Future<int> insertOrUpdate(Pharmacy pharmacy) async {
    final db = await DatabaseHelper.instance.database;
    final existing = await getByPartyCode(pharmacy.partyCode);
    if (existing != null) {
      final updatedMap = pharmacy.toMap();
      await db.update(
        'pharmacies',
        updatedMap,
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return existing.id!;
    } else {
      return await db.insert('pharmacies', pharmacy.toMap());
    }
  }

  /// Updates notes on the pharmacy row only — notes are user-managed and persist across imports.
  Future<int> updateNotes(int pharmacyId, String notes) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      'pharmacies',
      {'notes': notes},
      where: 'id = ?',
      whereArgs: [pharmacyId],
    );
  }

  /// Deletes a pharmacy and all its associated call reminders cleanly.
  Future<void> deletePharmacy(int pharmacyId) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.delete(
        'reminders',
        where: 'pharmacy_id = ? AND reminder_type = ?',
        whereArgs: [pharmacyId, 'pharmacy'],
      );
      await txn.delete(
        'pharmacies',
        where: 'id = ?',
        whereArgs: [pharmacyId],
      );
    });
  }

  /// Sorted list of distinct, non-null city values for filter dropdowns.
  Future<List<String>> getDistinctCities() async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.rawQuery('''
      SELECT DISTINCT TRIM(city) AS city 
      FROM pharmacies 
      WHERE city IS NOT NULL AND TRIM(city) != ''
      ORDER BY city COLLATE NOCASE ASC
    ''');
    return results.map((row) => row['city'] as String).toList();
  }

  /// Sorted list of distinct, non-null category values for filter dropdowns.
  Future<List<String>> getDistinctCategories() async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.rawQuery('''
      SELECT DISTINCT TRIM(category) AS category 
      FROM pharmacies 
      WHERE category IS NOT NULL AND TRIM(category) != ''
      ORDER BY category COLLATE NOCASE ASC
    ''');
    return results.map((row) => row['category'] as String).toList();
  }

  /// Returns pharmacies matching provided filters (AND logic), sorted by total_amount according to sortOrder ('DESC' or 'ASC').
  Future<List<Pharmacy>> getFilteredPharmacies({
    String? city,
    String? salesman,
    String? category,
    String sortOrder = 'DESC',
  }) async {
    final db = await DatabaseHelper.instance.database;

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (city != null && city.trim().isNotEmpty) {
      whereClauses.add("TRIM(city) = ? COLLATE NOCASE");
      whereArgs.add(city.trim());
    }

    if (salesman != null && salesman.trim().isNotEmpty) {
      whereClauses.add("TRIM(salesman) = ? COLLATE NOCASE");
      whereArgs.add(salesman.trim());
    }

    if (category != null && category.trim().isNotEmpty) {
      whereClauses.add("TRIM(category) = ? COLLATE NOCASE");
      whereArgs.add(category.trim());
    }

    String query = 'SELECT * FROM pharmacies';
    if (whereClauses.isNotEmpty) {
      query += ' WHERE ${whereClauses.join(' AND ')}';
    }
    final order = sortOrder.toUpperCase() == 'ASC' ? 'ASC' : 'DESC';
    query += ' ORDER BY COALESCE(total_amount, 0) $order, name COLLATE NOCASE ASC';

    final maps = await db.rawQuery(query, whereArgs);
    return maps.map((map) => Pharmacy.fromMap(map)).toList();
  }

  /// Matches if salesman name LIKE query, OR any of their pharmacies' city LIKE query, with optional city filter.
  Future<List<SalesmanSummary>> searchSalesmen(String query, {String? city}) async {
    final db = await DatabaseHelper.instance.database;

    String sql = '''
      SELECT 
        TRIM(salesman) AS salesman, 
        COUNT(id) AS pharmacy_count,
        COALESCE(SUM(total_amount), 0.0) AS total_due
      FROM pharmacies
      WHERE salesman IS NOT NULL AND TRIM(salesman) != ''
        AND (salesman LIKE ? OR city LIKE ?)
    ''';
    final whereArgs = <dynamic>['%$query%', '%$query%'];

    if (city != null && city.trim().isNotEmpty) {
      sql += ' AND TRIM(city) = ? COLLATE NOCASE';
      whereArgs.add(city.trim());
    }

    sql += '''
      GROUP BY TRIM(salesman) COLLATE NOCASE
      ORDER BY total_due DESC, salesman COLLATE NOCASE ASC
    ''';

    final results = await db.rawQuery(sql, whereArgs);

    return results.map((row) {
      return SalesmanSummary(
        salesman: row['salesman'] as String,
        pharmacyCount: (row['pharmacy_count'] as num).toInt(),
        totalDue: (row['total_due'] as num).toDouble(),
      );
    }).toList();
  }

  /// Returns aggregated summary grouped by salesman, sorted by totalDue DESC.
  Future<List<SalesmanSummary>> getSalesmenSummary({String? city}) async {
    final db = await DatabaseHelper.instance.database;

    String sql = '''
      SELECT 
        TRIM(salesman) AS salesman, 
        COUNT(id) AS pharmacy_count,
        COALESCE(SUM(total_amount), 0.0) AS total_due
      FROM pharmacies
      WHERE salesman IS NOT NULL AND TRIM(salesman) != ''
    ''';
    final whereArgs = <dynamic>[];

    if (city != null && city.trim().isNotEmpty) {
      sql += ' AND TRIM(city) = ? COLLATE NOCASE';
      whereArgs.add(city.trim());
    }

    sql += '''
      GROUP BY TRIM(salesman) COLLATE NOCASE
      ORDER BY total_due DESC, salesman COLLATE NOCASE ASC
    ''';

    final results = await db.rawQuery(sql, whereArgs);

    return results.map((row) {
      return SalesmanSummary(
        salesman: row['salesman'] as String,
        pharmacyCount: (row['pharmacy_count'] as num).toInt(),
        totalDue: (row['total_due'] as num).toDouble(),
      );
    }).toList();
  }

  /// Returns all pharmacies assigned to a specific salesman, sorted by total_amount DESC.
  Future<List<Pharmacy>> getPharmaciesBySalesman(String salesmanName) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.rawQuery('''
      SELECT * FROM pharmacies 
      WHERE TRIM(salesman) = ? COLLATE NOCASE
      ORDER BY COALESCE(total_amount, 0) DESC, name COLLATE NOCASE ASC
    ''', [salesmanName.trim()]);
    return maps.map((map) => Pharmacy.fromMap(map)).toList();
  }

  /// Insert or update a salesman's phone number. Safe to call repeatedly with
  /// the same name — matches case-insensitively via the table's COLLATE NOCASE key.
  Future<void> upsertSalesmanPhone(String name, String? phoneNumber, {DatabaseExecutor? executor}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;
    final db = executor ?? await DatabaseHelper.instance.database;
    await db.rawInsert('''
      INSERT INTO salesmen (name, phone_number) VALUES (?, ?)
      ON CONFLICT(name) DO UPDATE SET phone_number = excluded.phone_number
      WHERE excluded.phone_number IS NOT NULL AND TRIM(excluded.phone_number) != ''
    ''', [trimmedName, phoneNumber]);
  }

  /// Map of salesman name (lowercased, trimmed) -> phone number, for bulk lookups in lists.
  Future<Map<String, String>> getAllSalesmanPhones() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('salesmen', where: "phone_number IS NOT NULL AND TRIM(phone_number) != ''");
    final map = <String, String>{};
    for (final row in rows) {
      final name = (row['name'] as String).toLowerCase().trim();
      map[name] = row['phone_number'] as String;
    }
    return map;
  }

  /// Single lookup for one salesman's phone number, or null if not on file.
  Future<String?> getSalesmanPhone(String name) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'salesmen',
      columns: ['phone_number'],
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [name.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['phone_number'] as String?;
  }
}
