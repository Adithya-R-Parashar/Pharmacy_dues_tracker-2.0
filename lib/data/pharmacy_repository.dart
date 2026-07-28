import '../models/pharmacy.dart';
import 'database_helper.dart';
import 'invoice_repository.dart';
import '../services/due_calculator.dart';

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

class SalesmanPharmacyInfo {
  final Pharmacy pharmacy;
  final double totalDue;
  final int openInvoiceCount;
  final UrgencyLevel urgency;

  SalesmanPharmacyInfo({
    required this.pharmacy,
    required this.totalDue,
    required this.openInvoiceCount,
    required this.urgency,
  });
}

class PharmacyRepository {
  Future<List<Pharmacy>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('pharmacies');
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
      'SELECT * FROM pharmacies WHERE name LIKE ? OR city LIKE ? COLLATE NOCASE',
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

  /// Returns pharmacies matching ALL provided filters (AND logic)
  Future<List<SalesmanPharmacyInfo>> getFilteredPharmacies({
    String? city,
    String? salesman,
    String? dueOnDate,
  }) async {
    final db = await DatabaseHelper.instance.database;
    
    String query = 'SELECT p.* FROM pharmacies p';
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (dueOnDate != null) {
      query += ' JOIN invoices i ON p.id = i.pharmacy_id';
      whereClauses.add("i.status = 'open' AND i.due_date = ?");
      whereArgs.add(dueOnDate);
    }

    if (city != null && city.trim().isNotEmpty) {
      whereClauses.add("TRIM(p.city) = ? COLLATE NOCASE");
      whereArgs.add(city.trim());
    }

    if (salesman != null && salesman.trim().isNotEmpty) {
      whereClauses.add("TRIM(p.salesman) = ? COLLATE NOCASE");
      whereArgs.add(salesman.trim());
    }

    if (whereClauses.isNotEmpty) {
      query += ' WHERE ${whereClauses.join(' AND ')}';
    }

    if (dueOnDate != null) {
      query += ' GROUP BY p.id';
    }

    final maps = await db.rawQuery(query, whereArgs);
    final result = <SalesmanPharmacyInfo>[];
    final invoiceRepo = InvoiceRepository();

    for (final map in maps) {
      final pharmacy = Pharmacy.fromMap(map);
      final due = await invoiceRepo.getTotalDueForPharmacy(pharmacy.id!);
      final openInvoices = await invoiceRepo.getOpenByPharmacy(pharmacy.id!);

      var highestUrgency = UrgencyLevel.normal;
      for (final inv in openInvoices) {
        final urgency = DueCalculator.getUrgency(inv.dueDate);
        if (urgency == UrgencyLevel.overdue) {
          highestUrgency = UrgencyLevel.overdue;
          break;
        } else if (urgency == UrgencyLevel.warning) {
          highestUrgency = UrgencyLevel.warning;
        }
      }

      result.add(SalesmanPharmacyInfo(
        pharmacy: pharmacy,
        totalDue: due,
        openInvoiceCount: openInvoices.length,
        urgency: highestUrgency,
      ));
    }

    // Sort: most urgent first (overdue = index 0, warning = index 1, normal = index 2), then total due descending
    result.sort((a, b) {
      if (a.urgency != b.urgency) {
        return a.urgency.index.compareTo(b.urgency.index);
      }
      return b.totalDue.compareTo(a.totalDue);
    });

    return result;
  }

  /// Matches if salesman name LIKE query, OR any of their pharmacies' city LIKE query, with optional city filter.
  Future<List<SalesmanSummary>> searchSalesmen(String query, {String? city}) async {
    final db = await DatabaseHelper.instance.database;
    
    String sql = '''
      SELECT 
        TRIM(p.salesman) AS salesman, 
        COUNT(DISTINCT p.id) AS pharmacy_count,
        COALESCE(SUM(CASE WHEN i.status = 'open' THEN i.due_amount ELSE 0 END), 0.0) AS total_due
      FROM pharmacies p
      LEFT JOIN invoices i ON p.id = i.pharmacy_id
      WHERE p.salesman IS NOT NULL AND TRIM(p.salesman) != ''
        AND (p.salesman LIKE ? OR p.city LIKE ?)
    ''';
    final whereArgs = <dynamic>['%$query%', '%$query%'];

    if (city != null && city.trim().isNotEmpty) {
      sql += '''
        AND TRIM(p.salesman) COLLATE NOCASE IN (
          SELECT DISTINCT TRIM(salesman) FROM pharmacies WHERE TRIM(city) = ? COLLATE NOCASE
        )
      ''';
      whereArgs.add(city.trim());
    }

    sql += '''
      GROUP BY TRIM(p.salesman) COLLATE NOCASE
      ORDER BY total_due DESC, salesman COLLATE NOCASE ASC
    ''';

    final results = await db.rawQuery(sql, whereArgs);

    return results.map((row) {
      return SalesmanSummary(
        salesman: row['salesman'] as String,
        pharmacyCount: row['pharmacy_count'] as int,
        totalDue: (row['total_due'] as num).toDouble(),
      );
    }).toList();
  }

  /// Single aggregate query (JOIN + GROUP BY) case-insensitively and trimmed, excluding null/blank salesmen, with optional city filter.
  Future<List<SalesmanSummary>> getSalesmenSummary({String? city}) async {
    final db = await DatabaseHelper.instance.database;
    
    String query = '''
      SELECT 
        TRIM(p.salesman) AS salesman, 
        COUNT(DISTINCT p.id) AS pharmacy_count,
        COALESCE(SUM(CASE WHEN i.status = 'open' THEN i.due_amount ELSE 0 END), 0.0) AS total_due
      FROM pharmacies p
      LEFT JOIN invoices i ON p.id = i.pharmacy_id
      WHERE p.salesman IS NOT NULL AND TRIM(p.salesman) != ''
    ''';
    
    final whereArgs = <dynamic>[];
    if (city != null && city.trim().isNotEmpty) {
      query += '''
        AND TRIM(p.salesman) COLLATE NOCASE IN (
          SELECT DISTINCT TRIM(salesman) FROM pharmacies WHERE TRIM(city) = ? COLLATE NOCASE
        )
      ''';
      whereArgs.add(city.trim());
    }
    
    query += '''
      GROUP BY TRIM(p.salesman) COLLATE NOCASE
      ORDER BY total_due DESC, salesman COLLATE NOCASE ASC
    ''';
    
    final results = await db.rawQuery(query, whereArgs);

    return results.map((row) {
      return SalesmanSummary(
        salesman: row['salesman'] as String,
        pharmacyCount: row['pharmacy_count'] as int,
        totalDue: (row['total_due'] as num).toDouble(),
      );
    }).toList();
  }

  /// Fetches all pharmacies matching the salesman Name case-insensitively and trimmed, 
  /// with total dues, invoice counts, and urgency levels, sorted most urgent first.
  Future<List<SalesmanPharmacyInfo>> getPharmaciesBySalesman(String salesmanName) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'pharmacies',
      where: 'TRIM(salesman) = ? COLLATE NOCASE',
      whereArgs: [salesmanName.trim()],
    );

    final result = <SalesmanPharmacyInfo>[];
    final invoiceRepo = InvoiceRepository();

    for (final map in maps) {
      final pharmacy = Pharmacy.fromMap(map);
      final due = await invoiceRepo.getTotalDueForPharmacy(pharmacy.id!);
      final openInvoices = await invoiceRepo.getOpenByPharmacy(pharmacy.id!);

      var highestUrgency = UrgencyLevel.normal;
      for (final inv in openInvoices) {
        final urgency = DueCalculator.getUrgency(inv.dueDate);
        if (urgency == UrgencyLevel.overdue) {
          highestUrgency = UrgencyLevel.overdue;
          break;
        } else if (urgency == UrgencyLevel.warning) {
          highestUrgency = UrgencyLevel.warning;
        }
      }

      result.add(SalesmanPharmacyInfo(
        pharmacy: pharmacy,
        totalDue: due,
        openInvoiceCount: openInvoices.length,
        urgency: highestUrgency,
      ));
    }

    // Sort: most urgent first (overdue = index 0, warning = index 1, normal = index 2), then total due descending
    result.sort((a, b) {
      if (a.urgency != b.urgency) {
        return a.urgency.index.compareTo(b.urgency.index);
      }
      return b.totalDue.compareTo(a.totalDue);
    });

    return result;
  }
}
