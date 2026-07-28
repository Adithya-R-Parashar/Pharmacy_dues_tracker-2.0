import 'dart:typed_data';
import 'package:excel/excel.dart';

class ExcelTestGenerator {
  /// Generates the flat-format Excel bytes (used for testing flat files and regressions).
  static Uint8List generateTestExcelBytes() {
    final excel = Excel.createExcel();
    final sheet = excel.sheets.values.first;

    // Header row
    sheet.appendRow([
      TextCellValue('Party code'),
      TextCellValue('party name'),
      TextCellValue('transaction number'),
      TextCellValue('phone number'),
      TextCellValue('date'),
      TextCellValue('amount'),
      TextCellValue('due amount'),
      TextCellValue('days'),
      TextCellValue('due date'),
    ]);

    // Row 2: Valid row (Pharmacy A, invoice 1)
    sheet.appendRow([
      TextCellValue('P-2001'),
      TextCellValue('Alpha Meds'),
      TextCellValue('INV-ABC-123'),
      TextCellValue('123456789'),
      TextCellValue('2026-06-15'),
      DoubleCellValue(1200.0),
      DoubleCellValue(1200.0),
      IntCellValue(10),
      TextCellValue('2026-07-10'),
    ]);

    // Row 3: Duplicate pharmacy (Pharmacy A, invoice 2)
    sheet.appendRow([
      TextCellValue('P-2001'),
      TextCellValue('Alpha Meds'),
      TextCellValue('INV-ABC-456'),
      TextCellValue('123456789'),
      TextCellValue('2026-06-20'),
      DoubleCellValue(800.0),
      DoubleCellValue(800.0),
      IntCellValue(15),
      TextCellValue('2026-07-15'),
    ]);

    // Row 4: Blank due date (should skip)
    sheet.appendRow([
      TextCellValue('P-2002'),
      TextCellValue('Beta Pharmacy'),
      TextCellValue('INV-XYZ-789'),
      TextCellValue('987654321'),
      TextCellValue('2026-06-10'),
      DoubleCellValue(1000.0),
      DoubleCellValue(1000.0),
      IntCellValue(0),
      TextCellValue(''), // Blank due date
    ]);

    // Row 5: Text in amount field (should skip)
    sheet.appendRow([
      TextCellValue('P-2003'),
      TextCellValue('Gamma Clinic'),
      TextCellValue('INV-DEF-999'),
      TextCellValue('555555555'),
      TextCellValue('2026-06-05'),
      TextCellValue('unparseable_text'),
      DoubleCellValue(500.0),
      IntCellValue(12),
      TextCellValue('2026-06-25'),
    ]);

    // Row 6: Valid, with another pharmacy, date as number/serial
    sheet.appendRow([
      TextCellValue('P-2004'),
      TextCellValue('Delta Pharmacy'),
      TextCellValue('INV-GHI-888'),
      TextCellValue('777777777'),
      IntCellValue(46193), // 2026-06-20
      DoubleCellValue(2000.0),
      DoubleCellValue(2000.0),
      IntCellValue(20),
      IntCellValue(46213), // 2026-07-10
    ]);

    // Row 7: Completely blank row
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    final fileBytes = excel.save();
    return Uint8List.fromList(fileBytes ?? []);
  }

  /// Generates the grouped-format Excel bytes matching the test requirement:
  /// - 2 pharmacy groups (Sunshine Pharmacy and Green Leaf)
  /// - 5 real invoices
  /// - 2 blank-continuation rows (where party code/name are blank and forward-filled)
  /// - 2 TOTAL rows (skipped silently)
  static Uint8List generateGroupedExcelBytes() {
    final excel = Excel.createExcel();
    final sheet = excel.sheets.values.first;

    // Header row with varied spacing/casing
    sheet.appendRow([
      TextCellValue('Party Code'),
      TextCellValue('Party Name'),
      TextCellValue('Transaction Number'),
      TextCellValue('Phone No'),
      TextCellValue('Date'),
      TextCellValue('Amount'),
      TextCellValue('Due Amount'),
      TextCellValue('Days'),
      TextCellValue('Due Date'),
      TextCellValue('Sales Man'),
    ]);

    // sunshine Group
    // Row 2: Sunshine Invoice 1
    sheet.appendRow([
      TextCellValue('SUN-101'),
      TextCellValue('Sunshine Pharmacy'),
      TextCellValue('INV-SUN-01'),
      TextCellValue('12345'),
      TextCellValue('2026-06-10'),
      DoubleCellValue(4000.0),
      DoubleCellValue(4000.0),
      IntCellValue(30),
      TextCellValue('2026-07-10'),
      TextCellValue('Ravi'),
    ]);

    // Row 3: Sunshine Invoice 2 (blank-continuation 1)
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('INV-SUN-02'),
      TextCellValue(''),
      TextCellValue('2026-06-12'),
      DoubleCellValue(3200.0),
      DoubleCellValue(3200.0),
      IntCellValue(30),
      TextCellValue('2026-07-12'),
      TextCellValue(''),
    ]);

    // Row 4: Sunshine Invoice 3 (blank-continuation 2)
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('INV-SUN-03'),
      TextCellValue(''),
      TextCellValue('2026-06-15'),
      DoubleCellValue(2000.0),
      DoubleCellValue(2000.0),
      IntCellValue(30),
      TextCellValue('2026-07-15'),
      TextCellValue(''),
    ]);

    // Row 5: Sunshine TOTAL Row (contains "total", should be skipped silently)
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue('Sunshine Pharmacy Total'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(9200.0),
      DoubleCellValue(9200.0),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    // Green Leaf Group
    // Row 6: Green Leaf Invoice 1
    sheet.appendRow([
      TextCellValue('GRN-202'),
      TextCellValue('Green Leaf'),
      TextCellValue('INV-GRN-01'),
      TextCellValue('67890'),
      TextCellValue('2026-06-20'),
      DoubleCellValue(2000.0),
      DoubleCellValue(2000.0),
      IntCellValue(30),
      TextCellValue('2026-07-20'),
      TextCellValue('Kumar'),
    ]);

    // Row 7: Green Leaf Invoice 2 (with flat/explicit fields)
    sheet.appendRow([
      TextCellValue('GRN-202'),
      TextCellValue('Green Leaf'),
      TextCellValue('INV-GRN-02'),
      TextCellValue('67890'),
      TextCellValue('2026-06-22'),
      DoubleCellValue(1500.0),
      DoubleCellValue(1500.0),
      IntCellValue(30),
      TextCellValue('2026-07-22'),
      TextCellValue('Kumar'),
    ]);

    // Row 8: Green Leaf TOTAL Row (contains "total", should be skipped silently)
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue('Green Leaf Total'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(3500.0),
      DoubleCellValue(3500.0),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    final fileBytes = excel.save();
    return Uint8List.fromList(fileBytes ?? []);
  }
}
