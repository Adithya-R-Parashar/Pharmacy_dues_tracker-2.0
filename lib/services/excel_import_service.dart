import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../data/database_helper.dart';
import '../data/city_alias_repository.dart';
import '../data/pharmacy_repository.dart';
import 'category_calculator.dart';

int _levenshteinDistance(String a, String b) {
  final la = a.length, lb = b.length;
  if (la == 0) return lb;
  if (lb == 0) return la;
  List<int> prev = List<int>.generate(lb + 1, (j) => j);
  List<int> curr = List<int>.filled(lb + 1, 0);
  for (int i = 1; i <= la; i++) {
    curr[0] = i;
    for (int j = 1; j <= lb; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      final deletion = prev[j] + 1;
      final insertion = curr[j - 1] + 1;
      final substitution = prev[j - 1] + cost;
      curr[j] = [deletion, insertion, substitution].reduce((x, y) => x < y ? x : y);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[lb];
}

/// Returns true if [haystack] contains [keyword] exactly, or contains a substring
/// close enough to [keyword] to be a likely typo (edit distance <= 1 for short
/// keywords, <= 2 for longer ones).
bool _fuzzyContains(String haystack, String keyword) {
  if (haystack.contains(keyword)) return true;
  final maxDistance = keyword.length <= 5 ? 1 : 2;
  final klen = keyword.length;
  for (int start = 0; start < haystack.length; start++) {
    for (int len = (klen - maxDistance).clamp(1, klen + maxDistance); len <= (klen + maxDistance) && start + len <= haystack.length; len++) {
      final window = haystack.substring(start, start + len);
      if (_levenshteinDistance(window, keyword) <= maxDistance) return true;
    }
  }
  return false;
}

class ImportResult {
  final int newPharmacies;
  final int matchedPharmacies;
  final int snapshotsUpdated;
  final int skippedInvalidRows;
  final List<String> skippedReasons;

  ImportResult({
    required this.newPharmacies,
    required this.matchedPharmacies,
    required this.snapshotsUpdated,
    required this.skippedInvalidRows,
    required this.skippedReasons,
  });

  @override
  String toString() {
    return 'ImportResult(\n'
        '  newPharmacies: $newPharmacies,\n'
        '  matchedPharmacies: $matchedPharmacies,\n'
        '  snapshotsUpdated: $snapshotsUpdated,\n'
        '  skippedInvalidRows: $skippedInvalidRows,\n'
        '  skippedReasons:\n'
        '    ${skippedReasons.isEmpty ? "None" : skippedReasons.join("\n    ")}\n'
        ')';
  }
}

class ExcelImportService {
  /// Converts an Excel CellValue to String representation.
  static String? cellValueToString(excel.CellValue? cellValue) {
    if (cellValue == null) return null;
    if (cellValue is excel.TextCellValue) return cellValue.value.text;
    if (cellValue is excel.IntCellValue) return cellValue.value.toString();
    if (cellValue is excel.DoubleCellValue) {
      final d = cellValue.value;
      if (d == d.truncateToDouble()) {
        return d.toInt().toString();
      }
      return d.toString();
    }
    if (cellValue is excel.BoolCellValue) return cellValue.value.toString();
    if (cellValue is excel.DateCellValue) {
      return '${cellValue.year.toString().padLeft(4, '0')}-${cellValue.month.toString().padLeft(2, '0')}-${cellValue.day.toString().padLeft(2, '0')}';
    }
    if (cellValue is excel.DateTimeCellValue) {
      return '${cellValue.year.toString().padLeft(4, '0')}-${cellValue.month.toString().padLeft(2, '0')}-${cellValue.day.toString().padLeft(2, '0')} ${cellValue.hour.toString().padLeft(2, '0')}:${cellValue.minute.toString().padLeft(2, '0')}:${cellValue.second.toString().padLeft(2, '0')}';
    }
    if (cellValue is excel.TimeCellValue) {
      return '${cellValue.hour.toString().padLeft(2, '0')}:${cellValue.minute.toString().padLeft(2, '0')}:${cellValue.second.toString().padLeft(2, '0')}';
    }
    if (cellValue is excel.FormulaCellValue) return cellValue.formula;
    return cellValue.toString();
  }

  /// Formats a DateTime as yyyy-MM-dd.
  static String formatDateOnly(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// Parses an Excel CellValue into a double.
  static double parseDouble(excel.CellValue? cellValue) {
    if (cellValue == null) throw const FormatException('Value is empty');
    if (cellValue is excel.IntCellValue) {
      return cellValue.value.toDouble();
    }
    if (cellValue is excel.DoubleCellValue) {
      return cellValue.value;
    }
    final str = cellValueToString(cellValue)?.trim();
    if (str == null || str.isEmpty) {
      throw const FormatException('Value is empty');
    }
    final parsed = double.tryParse(str);
    if (parsed != null) return parsed;
    throw FormatException('Invalid number format: $str');
  }

  /// Lets the user pick an Excel file from storage and runs the import process.
  Future<ImportResult?> pickAndImportExcel({Function(int processed, int total)? onProgress}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      return null;
    }

    return await importExcelFromBytes(bytes, onProgress: onProgress);
  }

  /// Decodes and parses Excel bytes, performing database updates and returning results.
  Future<ImportResult> importExcelFromBytes(Uint8List bytes, {Function(int processed, int total)? onProgress}) async {
    final parseResults = await compute(parseExcelIsolate, bytes);

    final parsedRows = parseResults['parsedRows'] as List<dynamic>;
    final int skippedInvalidRows = parseResults['skippedInvalidRows'] as int;
    final skippedReasons = List<String>.from(parseResults['skippedReasons']);

    int newPharmacies = 0;
    int matchedPharmacies = 0;
    int snapshotsUpdated = 0;

    final db = await DatabaseHelper.instance.database;

    final aliasesList = await CityAliasRepository().getAllAliases();
    final Map<String, String> aliasMap = {
      for (final alias in aliasesList) alias.rawValue.toLowerCase(): alias.canonicalCity
    };

    final todayDateStr = formatDateOnly(DateTime.now());

    await db.transaction((txn) async {
      final total = parsedRows.length;
      for (int i = 0; i < total; i++) {
        final row = parsedRows[i] as Map<String, dynamic>;

        final partyCode = row['partyCode'] as String;
        final partyName = row['partyName'] as String;
        final salesman = row['salesman'] as String?;
        final city = row['city'] as String?;
        final category = row['category'] as String?;
        final totalAmount = row['totalAmount'] as double;
        final resolvedCategory = (category != null && category.trim().isNotEmpty)
            ? category.trim()
            : CategoryCalculator.categoryForAmount(totalAmount);
        final resolvedCity = city != null ? (aliasMap[city.trim().toLowerCase()] ?? city.trim()) : null;
        final bucket121180 = row['bucket121180'] as double?;
        final bucket181270 = row['bucket181270'] as double?;
        final bucket271360 = row['bucket271360'] as double?;

        final existingPharmacyMap = await txn.query(
          'pharmacies',
          where: 'party_code = ?',
          whereArgs: [partyCode],
        );
        final isNewPharmacy = existingPharmacyMap.isEmpty;
        final now = DateTime.now();
        final nowStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

        if (isNewPharmacy) {
          await txn.insert('pharmacies', {
            'party_code': partyCode,
            'name': partyName,
            'salesman': salesman,
            'city': resolvedCity,
            'category': resolvedCategory,
            'total_amount': totalAmount,
            'bucket_121_180': bucket121180,
            'bucket_181_270': bucket181270,
            'bucket_271_360': bucket271360,
            'last_import_date': todayDateStr,
            'notes': null,
            'created_at': nowStr,
          });
          newPharmacies++;
        } else {
          final pharmacyId = existingPharmacyMap.first['id'] as int;
          await txn.update(
            'pharmacies',
            {
              'name': partyName,
              'salesman': salesman,
              'city': resolvedCity,
              'category': resolvedCategory,
              'total_amount': totalAmount,
              'bucket_121_180': bucket121180,
              'bucket_181_270': bucket181270,
              'bucket_271_360': bucket271360,
              'last_import_date': todayDateStr,
              // NEVER update notes or created_at
            },
            where: 'id = ?',
            whereArgs: [pharmacyId],
          );
          matchedPharmacies++;
          snapshotsUpdated++;
        }

        final salesmanName = salesman;
        final phone = row['phone'] as String?;
        if (salesmanName != null && salesmanName.trim().isNotEmpty && phone != null && phone.trim().isNotEmpty) {
          await PharmacyRepository().upsertSalesmanPhone(salesmanName, phone, executor: txn);
        }

        if (onProgress != null) {
          onProgress(i + 1, total);
        }
      }
    });

    return ImportResult(
      newPharmacies: newPharmacies,
      matchedPharmacies: matchedPharmacies,
      snapshotsUpdated: snapshotsUpdated,
      skippedInvalidRows: skippedInvalidRows,
      skippedReasons: skippedReasons,
    );
  }
}

/// Isolate worker function parsing Excel sheet bytes and returning metadata maps.
Map<String, dynamic> parseExcelIsolate(Uint8List bytes) {
  final excelObj = excel.Excel.decodeBytes(bytes);
  if (excelObj.tables.isEmpty) {
    throw Exception('Excel file contains no sheets.');
  }

  final sheet = excelObj.tables.values.first;
  if (sheet.rows.isEmpty) {
    throw Exception('The sheet is empty.');
  }

  int? partyCodeIdx;
  int? partyNameIdx;
  int? salesmanIdx;
  int? cityIdx;
  int? categoryIdx;
  int? phoneIdx;
  int? totalAmountIdx;
  int? bucket121180Idx;
  int? bucket181270Idx;
  int? bucket271360Idx;

  final headerRow = sheet.rows.first;
  for (int i = 0; i < headerRow.length; i++) {
    final cellVal = ExcelImportService.cellValueToString(headerRow[i]?.value)?.trim();
    if (cellVal == null) continue;

    final lower = cellVal.toLowerCase();
    final clean = lower.replaceAll(RegExp(r'[\s_\-\.\,\/\(\)\:]'), '');

    if (_fuzzyContains(clean, 'code') && partyCodeIdx == null) {
      partyCodeIdx = i;
    } else if (_fuzzyContains(clean, 'salesman') && salesmanIdx == null) {
      salesmanIdx = i;
    } else if ((_fuzzyContains(clean, 'phone') || _fuzzyContains(clean, 'mobile') || _fuzzyContains(clean, 'contact')) && phoneIdx == null) {
      phoneIdx = i;
    } else if ((_fuzzyContains(clean, 'city') || _fuzzyContains(clean, 'area')) && cityIdx == null) {
      cityIdx = i;
    } else if (clean.contains('121') && (clean.contains('150') || clean.contains('180')) && bucket121180Idx == null) {
      bucket121180Idx = i;
    } else if ((clean.contains('151') || clean.contains('181')) && clean.contains('270') && bucket181270Idx == null) {
      bucket181270Idx = i;
    } else if (clean.contains('271') && clean.contains('360') && bucket271360Idx == null) {
      bucket271360Idx = i;
    } else if (_fuzzyContains(clean, 'category') && categoryIdx == null) {
      categoryIdx = i;
    } else if ((_fuzzyContains(clean, 'amount') || _fuzzyContains(clean, 'due') || lower == 'total') && totalAmountIdx == null) {
      totalAmountIdx = i;
    } else if (_fuzzyContains(clean, 'party') && partyNameIdx == null) {
      partyNameIdx = i;
    }
  }

  if (partyCodeIdx == null || partyNameIdx == null || totalAmountIdx == null) {
    throw Exception(
      'Missing required columns in Excel sheet.\n'
      'Required: Party Code, Party Name, Total Amount.',
    );
  }

  final parsedRows = <Map<String, dynamic>>[];
  int skippedInvalidRows = 0;
  final skippedReasons = <String>[];

  String? lastPartyCode;
  String? lastPartyName;
  String? lastSalesman;
  String? lastCity;
  String? lastCategory;

  for (int r = 1; r < sheet.rows.length; r++) {
    final row = sheet.rows[r];

    bool isRowBlank = true;
    final mappedIndices = [
      partyCodeIdx,
      partyNameIdx,
      totalAmountIdx,
      bucket121180Idx,
      bucket181270Idx,
      bucket271360Idx,
      salesmanIdx,
      cityIdx,
      categoryIdx,
      phoneIdx,
    ];
    for (final idx in mappedIndices) {
      if (idx != null && idx < row.length) {
        final val = ExcelImportService.cellValueToString(row[idx]?.value);
        if (val != null && val.trim().isNotEmpty) {
          isRowBlank = false;
          break;
        }
      }
    }
    if (isRowBlank) {
      continue;
    }

    bool isTotalRow = false;
    for (final cell in row) {
      final val = ExcelImportService.cellValueToString(cell?.value);
      if (val != null && val.toLowerCase().contains('total')) {
        isTotalRow = true;
        break;
      }
    }
    if (isTotalRow) {
      continue;
    }

    final partyCodeVal = partyCodeIdx < row.length ? row[partyCodeIdx]?.value : null;
    final partyNameVal = partyNameIdx < row.length ? row[partyNameIdx]?.value : null;
    final salesmanVal = (salesmanIdx != null && salesmanIdx < row.length) ? row[salesmanIdx]?.value : null;
    final cityVal = (cityIdx != null && cityIdx < row.length) ? row[cityIdx]?.value : null;
    final categoryVal = (categoryIdx != null && categoryIdx < row.length) ? row[categoryIdx]?.value : null;
    final phoneVal = (phoneIdx != null && phoneIdx < row.length) ? row[phoneIdx]?.value : null;
    final totalAmountVal = totalAmountIdx < row.length ? row[totalAmountIdx]?.value : null;
    final bucket121180Val = (bucket121180Idx != null && bucket121180Idx < row.length) ? row[bucket121180Idx]?.value : null;
    final bucket181270Val = (bucket181270Idx != null && bucket181270Idx < row.length) ? row[bucket181270Idx]?.value : null;
    final bucket271360Val = (bucket271360Idx != null && bucket271360Idx < row.length) ? row[bucket271360Idx]?.value : null;

    final rawPartyCode = ExcelImportService.cellValueToString(partyCodeVal)?.trim();
    final rawPartyName = ExcelImportService.cellValueToString(partyNameVal)?.trim();
    final rawSalesman = ExcelImportService.cellValueToString(salesmanVal)?.trim();
    final rawCity = ExcelImportService.cellValueToString(cityVal)?.trim();
    final rawCategory = ExcelImportService.cellValueToString(categoryVal)?.trim();
    final phone = ExcelImportService.cellValueToString(phoneVal)?.trim();

    if (rawPartyCode != null && rawPartyCode.isNotEmpty) {
      lastPartyCode = rawPartyCode;
    }
    if (rawPartyName != null && rawPartyName.isNotEmpty) {
      lastPartyName = rawPartyName;
    }
    if (rawSalesman != null && rawSalesman.isNotEmpty) {
      lastSalesman = rawSalesman;
    }
    if (rawCity != null && rawCity.isNotEmpty) {
      lastCity = rawCity;
    }
    if (rawCategory != null && rawCategory.isNotEmpty) {
      lastCategory = rawCategory;
    }

    final partyCode = (rawPartyCode == null || rawPartyCode.isEmpty) ? lastPartyCode : rawPartyCode;
    final partyName = (rawPartyName == null || rawPartyName.isEmpty) ? lastPartyName : rawPartyName;
    final salesman = (rawSalesman == null || rawSalesman.isEmpty) ? lastSalesman : rawSalesman;
    final city = (rawCity == null || rawCity.isEmpty) ? lastCity : rawCity;
    final category = (rawCategory == null || rawCategory.isEmpty) ? lastCategory : rawCategory;

    if (partyCode == null || partyCode.isEmpty) {
      skippedInvalidRows++;
      skippedReasons.add('Row ${r + 1}: missing Party code');
      continue;
    }
    if (partyName == null || partyName.isEmpty) {
      skippedInvalidRows++;
      skippedReasons.add('Row ${r + 1}: missing Party name');
      continue;
    }

    double? parsedBucket121180;
    if (bucket121180Val != null) {
      try {
        parsedBucket121180 = ExcelImportService.parseDouble(bucket121180Val);
      } catch (_) {}
    }

    double? parsedBucket181270;
    if (bucket181270Val != null) {
      try {
        parsedBucket181270 = ExcelImportService.parseDouble(bucket181270Val);
      } catch (_) {}
    }

    double? parsedBucket271360;
    if (bucket271360Val != null) {
      try {
        parsedBucket271360 = ExcelImportService.parseDouble(bucket271360Val);
      } catch (_) {}
    }

    double? parsedTotalAmount;
    try {
      parsedTotalAmount = ExcelImportService.parseDouble(totalAmountVal);
    } catch (_) {
      // Total Amount cell may be a formula (e.g. "=D2+E2+F2") rather than a literal
      // number — the excel package only exposes the formula text, not its computed
      // result, so fall back to computing it ourselves as the sum of the three
      // aging buckets, which is what that formula represents in practice.
      final hasAnyBucket = parsedBucket121180 != null || parsedBucket181270 != null || parsedBucket271360 != null;
      if (hasAnyBucket) {
        parsedTotalAmount = (parsedBucket121180 ?? 0) + (parsedBucket181270 ?? 0) + (parsedBucket271360 ?? 0);
      }
    }
    if (parsedTotalAmount == null) {
      skippedInvalidRows++;
      skippedReasons.add('Row ${r + 1}: missing or invalid total amount value');
      continue;
    }

    parsedRows.add({
      'partyCode': partyCode,
      'partyName': partyName,
      'salesman': salesman,
      'city': city,
      'category': category,
      'phone': phone,
      'totalAmount': parsedTotalAmount,
      'bucket121180': parsedBucket121180,
      'bucket181270': parsedBucket181270,
      'bucket271360': parsedBucket271360,
      'rowIndex': r + 1,
    });
  }

  return {
    'parsedRows': parsedRows,
    'skippedInvalidRows': skippedInvalidRows,
    'skippedReasons': skippedReasons,
  };
}
