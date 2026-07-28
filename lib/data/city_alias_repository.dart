import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class CityAlias {
  final String rawValue;
  final String canonicalCity;
  final String createdAt;

  CityAlias({
    required this.rawValue,
    required this.canonicalCity,
    required this.createdAt,
  });

  factory CityAlias.fromMap(Map<String, dynamic> map) {
    return CityAlias(
      rawValue: map['raw_value'] as String,
      canonicalCity: map['canonical_city'] as String,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'raw_value': rawValue,
      'canonical_city': canonicalCity,
      'created_at': createdAt,
    };
  }
}

class CityAliasRepository {
  Future<List<CityAlias>> getAllAliases() async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.query(
      'city_aliases',
      orderBy: 'raw_value COLLATE NOCASE ASC',
    );
    return results.map((row) => CityAlias.fromMap(row)).toList();
  }

  Future<String> resolveCity(String rawCity) async {
    final trimmed = rawCity.trim();
    if (trimmed.isEmpty) return trimmed;

    final db = await DatabaseHelper.instance.database;
    final results = await db.query(
      'city_aliases',
      columns: ['canonical_city'],
      where: 'raw_value = ?',
      whereArgs: [trimmed],
    );

    if (results.isNotEmpty) {
      return results.first['canonical_city'] as String;
    }
    return trimmed;
  }

  Future<void> mergeCities(List<String> variantCities, String canonicalCity) async {
    final db = await DatabaseHelper.instance.database;
    final nowStr = DateTime.now().toIso8601String();
    final canonicalTrimmed = canonicalCity.trim();

    await db.transaction((txn) async {
      // 1. Insert/update city_aliases for variant cities (excluding canonical itself)
      for (final variant in variantCities) {
        final variantTrimmed = variant.trim();
        if (variantTrimmed.isEmpty || variantTrimmed.toLowerCase() == canonicalTrimmed.toLowerCase()) {
          continue;
        }

        // Insert or replace variant alias
        await txn.insert(
          'city_aliases',
          {
            'raw_value': variantTrimmed,
            'canonical_city': canonicalTrimmed,
            'created_at': nowStr,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 2. Retroactively update all pharmacies in variantCities to canonicalCity case-insensitively
      for (final variant in variantCities) {
        await txn.update(
          'pharmacies',
          {'city': canonicalTrimmed},
          where: 'TRIM(city) = ? COLLATE NOCASE',
          whereArgs: [variant.trim()],
        );
      }
    });
  }

  Future<void> removeAlias(String rawValue) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'city_aliases',
      where: 'raw_value = ?',
      whereArgs: [rawValue.trim()],
    );
  }
}
