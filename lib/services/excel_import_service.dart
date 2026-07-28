import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../data/database_helper.dart';
import '../data/city_alias_repository.dart';

class ImportResult {
  final int newPharmacies;
  final int matchedPharmacies;
  final int newInvoices;
  final int updatedInvoices;
  final int skippedPaidInvoices;
  final int skippedInvalidRows;
  final List<String> skippedReasons;

  ImportResult({
    required this.newPharmacies,
    required this.matchedPharmacies,
    required this.newInvoices,
    required this.updatedInvoices,
    required this.skippedPaidInvoices,
    required this.skippedInvalidRows,
    required this.skippedReasons,
  });

  @override
  String toString() {
    return 'ImportResult(\n'
        '  newPharmacies: $newPharmacies,\n'
        '  matchedPharmacies: $matchedPharmacies,\n'
        '  newInvoices: $newInvoices,\n'
        '  updatedInvoices: $updatedInvoices,\n'
        '  skippedPaidInvoices: $skippedPaidInvoices,\n'
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
    if (cellValue is excel.DoubleCellValue) return cellValue.value.toString();
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

  /// Parses an Excel CellValue into a yyyy-MM-dd Date string.
  static String parseDate(excel.CellValue? cellValue) {
    if (cellValue == null) throw const FormatException('Date cell is empty');

    if (cellValue is excel.DateCellValue) {
      return '${cellValue.year.toString().padLeft(4, '0')}-${cellValue.month.toString().padLeft(2, '0')}-${cellValue.day.toString().padLeft(2, '0')}';
    }
    if (cellValue is excel.DateTimeCellValue) {
      return '${cellValue.year.toString().padLeft(4, '0')}-${cellValue.month.toString().padLeft(2, '0')}-${cellValue.day.toString().padLeft(2, '0')}';
    }

    // Handle number fallback (Excel serial numbers)
    if (cellValue is excel.IntCellValue) {
      final serial = cellValue.value;
      final parsedDt = DateTime(1899, 12, 30).add(Duration(days: serial));
      return formatDateOnly(parsedDt);
    }
    if (cellValue is excel.DoubleCellValue) {
      final serial = cellValue.value.toInt();
      final parsedDt = DateTime(1899, 12, 30).add(Duration(days: serial));
      return formatDateOnly(parsedDt);
    }

    // Handle string format conversion
    final stringVal = cellValueToString(cellValue)?.trim();
    if (stringVal == null || stringVal.isEmpty) {
      throw const FormatException('Date cell is empty');
    }

    // Check yyyy-MM-dd
    final regYmd = RegExp(r'^(\d{4})[./-](\d{1,2})[./-](\d{1,2})$');
    final matchYmd = regYmd.firstMatch(stringVal);
    if (matchYmd != null) {
      final year = int.parse(matchYmd.group(1)!);
      final month = int.parse(matchYmd.group(2)!);
      final day = int.parse(matchYmd.group(3)!);
      return formatDateOnly(DateTime(year, month, day));
    }

    // Check dd-MM-yyyy or dd/MM/yyyy
    final regDmy = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})$');
    final matchDmy = regDmy.firstMatch(stringVal);
    if (matchDmy != null) {
      final day = int.parse(matchDmy.group(1)!);
      final month = int.parse(matchDmy.group(2)!);
      final year = int.parse(matchDmy.group(3)!);
      return formatDateOnly(DateTime(year, month, day));
    }

    // Check dd-MMM-yy or dd-MMM-yyyy (e.g. 04-Jul-26)
    final regDmmmy = RegExp(r'^(\d{1,2})[./-]([a-zA-Z]{3})[./-](\d{2,4})$');
    final matchDmmmy = regDmmmy.firstMatch(stringVal);
    if (matchDmmmy != null) {
      final day = int.parse(matchDmmmy.group(1)!);
      final monthStr = matchDmmmy.group(2)!.toLowerCase();
      final yearStr = matchDmmmy.group(3)!;
      final year = yearStr.length == 2 ? 2000 + int.parse(yearStr) : int.parse(yearStr);

      const monthsMap = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
      };
      final month = monthsMap[monthStr];
      if (month != null) {
        return formatDateOnly(DateTime(year, month, day));
      }
    }

    // Direct DateTime tryParse check
    final parsedDt = DateTime.tryParse(stringVal);
    if (parsedDt != null) {
      return formatDateOnly(parsedDt);
    }

    throw FormatException('Invalid date format: $stringVal');
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
    // 1. Perform Excel decoding & parsing in a background isolate (CPU bound)
    final parseResults = await compute(parseExcelIsolate, bytes);

    final parsedRows = parseResults['parsedRows'] as List<dynamic>;
    final int skippedInvalidRows = parseResults['skippedInvalidRows'] as int;
    final skippedReasons = List<String>.from(parseResults['skippedReasons']);

    int newPharmacies = 0;
    int matchedPharmacies = 0;
    int newInvoices = 0;
    int updatedInvoices = 0;
    int skippedPaidInvoices = 0;

    final db = await DatabaseHelper.instance.database;

    final aliasesList = await CityAliasRepository().getAllAliases();
    final Map<String, String> aliasMap = {
      for (final alias in aliasesList) alias.rawValue.toLowerCase(): alias.canonicalCity
    };

    // 2. Perform all database writes inside a single atomic SQL transaction (I/O bound)
    await db.transaction((txn) async {
      final total = parsedRows.length;
      for (int i = 0; i < total; i++) {
        final row = parsedRows[i] as Map<String, dynamic>;

        final partyCode = row['partyCode'] as String;
        final partyName = row['partyName'] as String;
        final salesman = row['salesman'] as String?;
        final city = row['city'] as String?;
        final resolvedCity = city != null ? (aliasMap[city.trim().toLowerCase()] ?? city.trim()) : null;
        final transactionNumber = row['transactionNumber'] as String;
        final invoiceDate = row['invoiceDate'] as String?;
        final amount = row['amount'] as double;
        final dueAmount = row['dueAmount'] as double;
        final dueDate = row['dueDate'] as String;

        // Pharmacy upsert
        final existingPharmacyMap = await txn.query(
          'pharmacies',
          where: 'party_code = ?',
          whereArgs: [partyCode],
        );
        final isNewPharmacy = existingPharmacyMap.isEmpty;
        final now = DateTime.now();
        final nowStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

        int pharmacyId;
        if (isNewPharmacy) {
          pharmacyId = await txn.insert('pharmacies', {
            'party_code': partyCode,
            'name': partyName,
            'salesman': salesman,
            'city': resolvedCity,
            'created_at': nowStr,
          });
          newPharmacies++;
        } else {
          pharmacyId = existingPharmacyMap.first['id'] as int;
          await txn.update(
            'pharmacies',
            {
              'name': partyName,
              'salesman': salesman, // Always overwrite
              'city': resolvedCity, // Always overwrite
            },
            where: 'id = ?',
            whereArgs: [pharmacyId],
          );
          matchedPharmacies++;
        }

        // Invoice upsert
        final existingInvoiceMaps = await txn.query(
          'invoices',
          where: 'pharmacy_id = ? AND invoice_number = ?',
          whereArgs: [pharmacyId, transactionNumber],
        );

        if (existingInvoiceMaps.isNotEmpty) {
          final status = existingInvoiceMaps.first['status'] as String;
          if (status == 'paid') {
            skippedPaidInvoices++;
          } else {
            final invoiceId = existingInvoiceMaps.first['id'] as int;
            await txn.update(
              'invoices',
              {
                'amount': amount,
                'due_amount': dueAmount,
                'due_date': dueDate,
              },
              where: 'id = ?',
              whereArgs: [invoiceId],
            );
            updatedInvoices++;
          }
        } else {
          await txn.insert('invoices', {
            'pharmacy_id': pharmacyId,
            'invoice_number': transactionNumber,
            'invoice_date': invoiceDate,
            'amount': amount,
            'due_amount': dueAmount,
            'due_date': dueDate,
            'status': 'open',
            'created_at': nowStr,
          });
          newInvoices++;
        }

        // Trigger progress callback if present
        if (onProgress != null) {
          onProgress(i + 1, total);
        }
      }
    });

    return ImportResult(
      newPharmacies: newPharmacies,
      matchedPharmacies: matchedPharmacies,
      newInvoices: newInvoices,
      updatedInvoices: updatedInvoices,
      skippedPaidInvoices: skippedPaidInvoices,
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
  int? transactionNumberIdx;
  int? dateIdx;
  int? amountIdx;
  int? dueAmountIdx;
  int? dueDateIdx;

  // 1. Flexible Column Header matching using clean keyword matching rules
  final headerRow = sheet.rows.first;
  for (int i = 0; i < headerRow.length; i++) {
    final cellVal = ExcelImportService.cellValueToString(headerRow[i]?.value)?.trim();
    if (cellVal == null) continue;

    // clean space and punctuation for flexible containing check
    final clean = cellVal.replaceAll(RegExp(r'[\s_\-\.\,\/\(\)\:]'), '').toLowerCase();

    if (clean.contains('code')) {
      partyCodeIdx = i;
    } else if (clean.contains('salesman')) {
      salesmanIdx = i;
    } else if (clean.contains('city') || clean.contains('area')) {
      cityIdx = i;
    } else if (clean.contains('party') && !clean.contains('code')) {
      partyNameIdx = i;
    } else if (clean.contains('trn') || (clean.contains('transaction') && (clean.contains('number') || clean.contains('no')))) {
      transactionNumberIdx = i;
    } else if (clean.contains('due') && clean.contains('amount')) {
      dueAmountIdx = i;
    } else if (clean.contains('amount') && !clean.contains('due')) {
      amountIdx = i;
    } else if (clean.contains('due') && clean.contains('date')) {
      dueDateIdx = i;
    } else if (clean.contains('date') && !clean.contains('due')) {
      dateIdx = i;
    }
  }

  if (partyCodeIdx == null ||
      partyNameIdx == null ||
      transactionNumberIdx == null ||
      dateIdx == null ||
      amountIdx == null ||
      dueAmountIdx == null) {
    throw Exception(
      'Missing required columns in Excel sheet.\n'
      'Required: Party Code, Party Name, Transaction Number, Date, Amount, Due Amount.',
    );
  }

  final parsedRows = <Map<String, dynamic>>[];
  int skippedInvalidRows = 0;
  final skippedReasons = <String>[];

  // Tracking references for forward-filling
  String? lastPartyCode;
  String? lastPartyName;
  String? lastSalesman;
  String? lastCity;

  // 2. Process data rows
  for (int r = 1; r < sheet.rows.length; r++) {
    final row = sheet.rows[r];

    // Check if row is completely blank (all mapped values are blank/null)
    bool isRowBlank = true;
    final mappedIndices = [
      partyCodeIdx,
      partyNameIdx,
      transactionNumberIdx,
      dateIdx,
      amountIdx,
      dueAmountIdx,
      dueDateIdx,
      cityIdx,
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
      continue; // Silently skip completely blank rows
    }

    // Skip TOTAL/subtotal rows entirely
    bool isTotalRow = false;
    for (final cell in row) {
      final val = ExcelImportService.cellValueToString(cell?.value);
      if (val != null && val.toLowerCase().contains('total')) {
        isTotalRow = true;
        break;
      }
    }
    if (isTotalRow) {
      continue; // Silently skip subtotal summaries without logging
    }

    final partyCodeVal = partyCodeIdx < row.length ? row[partyCodeIdx]?.value : null;
    final partyNameVal = partyNameIdx < row.length ? row[partyNameIdx]?.value : null;
    final salesmanVal = (salesmanIdx != null && salesmanIdx < row.length) ? row[salesmanIdx]?.value : null;
    final cityVal = (cityIdx != null && cityIdx < row.length) ? row[cityIdx]?.value : null;
    final transactionNumberVal = transactionNumberIdx < row.length ? row[transactionNumberIdx]?.value : null;
    final dateVal = dateIdx < row.length ? row[dateIdx]?.value : null;
    final amountVal = amountIdx < row.length ? row[amountIdx]?.value : null;
    final dueAmountVal = dueAmountIdx < row.length ? row[dueAmountIdx]?.value : null;

    final rawPartyCode = ExcelImportService.cellValueToString(partyCodeVal)?.trim();
    final rawPartyName = ExcelImportService.cellValueToString(partyNameVal)?.trim();
    final rawSalesman = ExcelImportService.cellValueToString(salesmanVal)?.trim();
    final rawCity = ExcelImportService.cellValueToString(cityVal)?.trim();
    final transactionNumber = ExcelImportService.cellValueToString(transactionNumberVal)?.trim();

    // Track last non-blank pharmacy details
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

    // Forward-fill blank party_code/name/salesman/city if valid transaction number is present
    final partyCode = (rawPartyCode == null || rawPartyCode.isEmpty) ? lastPartyCode : rawPartyCode;
    final partyName = (rawPartyName == null || rawPartyName.isEmpty) ? lastPartyName : rawPartyName;
    final salesman = (rawSalesman == null || rawSalesman.isEmpty) ? lastSalesman : rawSalesman;
    final city = (rawCity == null || rawCity.isEmpty) ? lastCity : rawCity;

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
    if (transactionNumber == null || transactionNumber.isEmpty) {
      skippedInvalidRows++;
      skippedReasons.add('Row ${r + 1}: missing Transaction number');
      continue;
    }

    // Try to parse due date
    String? parsedDueDate;
    bool hasParsedDueDate = false;
    if (dueDateIdx != null && dueDateIdx < row.length) {
      final valStr = ExcelImportService.cellValueToString(row[dueDateIdx]?.value)?.trim();
      if (valStr != null && valStr.isNotEmpty) {
        try {
          parsedDueDate = ExcelImportService.parseDate(row[dueDateIdx]?.value);
          hasParsedDueDate = true;
        } catch (_) {
          // Fallback to invoice date
        }
      }
    }

    // Try to parse invoice date
    String? parsedInvoiceDate;
    bool hasParsedInvoiceDate = false;
    if (dateVal != null) {
      final str = ExcelImportService.cellValueToString(dateVal)?.trim();
      if (str != null && str.isNotEmpty) {
        try {
          parsedInvoiceDate = ExcelImportService.parseDate(dateVal);
          hasParsedInvoiceDate = true;
        } catch (_) {
          // If we also couldn't parse due date, this might be a skip
        }
      }
    }

    // Combine date validations
    if (!hasParsedDueDate) {
      if (hasParsedInvoiceDate && parsedInvoiceDate != null) {
        final invDateObj = DateTime.parse(parsedInvoiceDate);
        final computedDue = invDateObj.add(const Duration(days: 60));
        parsedDueDate = ExcelImportService.formatDateOnly(computedDue);
      } else {
        skippedInvalidRows++;
        skippedReasons.add('Row ${r + 1}: missing both date and due date, cannot determine due date');
        continue;
      }
    }

    // Amount & due amount
    final double parsedAmount;
    final double parsedDueAmount;
    try {
      parsedAmount = ExcelImportService.parseDouble(amountVal);
    } catch (_) {
      skippedInvalidRows++;
      skippedReasons.add('Row ${r + 1}: missing or invalid amount value');
      continue;
    }
    try {
      parsedDueAmount = ExcelImportService.parseDouble(dueAmountVal);
    } catch (_) {
      skippedInvalidRows++;
      skippedReasons.add('Row ${r + 1}: missing or invalid due amount value');
      continue;
    }

    parsedRows.add({
      'partyCode': partyCode,
      'partyName': partyName,
      'salesman': salesman,
      'city': city,
      'transactionNumber': transactionNumber,
      'invoiceDate': parsedInvoiceDate,
      'amount': parsedAmount,
      'dueAmount': parsedDueAmount,
      'dueDate': parsedDueDate,
      'rowIndex': r + 1,
    });
  }

  return {
    'parsedRows': parsedRows,
    'skippedInvalidRows': skippedInvalidRows,
    'skippedReasons': skippedReasons,
  };
}
