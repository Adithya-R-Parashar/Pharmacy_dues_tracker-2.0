import 'dart:typed_data';
import 'package:excel/excel.dart';

class ExcelTestGenerator {
  /// Generates sample Excel bytes containing aging bucket columns.
  static Uint8List generateGroupedExcelBytes() {
    final excel = Excel.createExcel();
    final sheet = excel.sheets.values.first;

    // Header row
    sheet.appendRow([
      TextCellValue('Party Code'),
      TextCellValue('Party Name'),
      TextCellValue('Sales Man'),
      TextCellValue('City'),
      TextCellValue('Amount'),
      TextCellValue('121 - 150 Days'),
      TextCellValue('151 - 270 Days'),
      TextCellValue('271 - 360 Days'),
    ]);

    // Row 1: Sunshine Pharmacy
    sheet.appendRow([
      TextCellValue('SUN-101'),
      TextCellValue('Sunshine Pharmacy'),
      TextCellValue('Ravi'),
      TextCellValue('Mumbai'),
      DoubleCellValue(9200.0),
      DoubleCellValue(4000.0),
      DoubleCellValue(3200.0),
      DoubleCellValue(2000.0),
    ]);

    // Row 2: Green Leaf
    sheet.appendRow([
      TextCellValue('GRN-202'),
      TextCellValue('Green Leaf'),
      TextCellValue('Kumar'),
      TextCellValue('Pune'),
      DoubleCellValue(3500.0),
      DoubleCellValue(2000.0),
      DoubleCellValue(1500.0),
      DoubleCellValue(0.0),
    ]);

    final fileBytes = excel.save();
    return Uint8List.fromList(fileBytes ?? []);
  }

  /// Generates sample Excel bytes for regression testing (including blank and invalid rows).
  static Uint8List generateTestExcelBytes() {
    final excel = Excel.createExcel();
    final sheet = excel.sheets.values.first;

    // Header row
    sheet.appendRow([
      TextCellValue('Party code'),
      TextCellValue('Party Name'),
      TextCellValue('Sales Man'),
      TextCellValue('City'),
      TextCellValue('Total Amount'),
      TextCellValue('121-180'),
      TextCellValue('181-270'),
      TextCellValue('271-360'),
    ]);

    // Row 2: Valid row (Alpha Meds)
    sheet.appendRow([
      TextCellValue('P-2001'),
      TextCellValue('Alpha Meds'),
      TextCellValue('Ravi'),
      TextCellValue('Delhi'),
      DoubleCellValue(2000.0),
      DoubleCellValue(1200.0),
      DoubleCellValue(800.0),
      DoubleCellValue(0.0),
    ]);

    // Row 3: Missing total amount (should skip)
    sheet.appendRow([
      TextCellValue('P-2002'),
      TextCellValue('Beta Pharmacy'),
      TextCellValue('Kumar'),
      TextCellValue('Mumbai'),
      TextCellValue(''), // Missing amount
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    // Row 4: Text in amount field (should skip)
    sheet.appendRow([
      TextCellValue('P-2003'),
      TextCellValue('Gamma Clinic'),
      TextCellValue('Ravi'),
      TextCellValue('Delhi'),
      TextCellValue('unparseable_text'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    // Row 5: Valid (Delta Pharmacy)
    sheet.appendRow([
      TextCellValue('P-2004'),
      TextCellValue('Delta Pharmacy'),
      TextCellValue('Suresh'),
      TextCellValue('Bangalore'),
      DoubleCellValue(4000.0),
      DoubleCellValue(2000.0),
      DoubleCellValue(1000.0),
      DoubleCellValue(1000.0),
    ]);

    // Row 6: Completely blank row
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    final fileBytes = excel.save();
    return Uint8List.fromList(fileBytes ?? []);
  }
}
