import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_dues_tracker/services/excel_import_service.dart';
import 'package:pharmacy_dues_tracker/services/excel_test_generator.dart';

void main() {
  group('Excel Import Parser Unit Tests', () {
    test('Grouped-format Excel sheet parses correctly', () {
      final bytes = ExcelTestGenerator.generateGroupedExcelBytes();
      final results = parseExcelIsolate(bytes);

      final parsedRows = results['parsedRows'] as List<dynamic>;
      final skippedInvalidRows = results['skippedInvalidRows'] as int;

      // Expect exactly 5 invoices (Row 2, 3, 4, 6, 7 in the sheet)
      expect(parsedRows.length, equals(5));
      expect(skippedInvalidRows, equals(0));

      // Row 1 (Sunshine Invoice 1): SUN-101, Sunshine Pharmacy
      expect(parsedRows[0]['partyCode'], equals('SUN-101'));
      expect(parsedRows[0]['partyName'], equals('Sunshine Pharmacy'));
      expect(parsedRows[0]['salesman'], equals('Ravi'));
      expect(parsedRows[0]['transactionNumber'], equals('INV-SUN-01'));
      expect(parsedRows[0]['amount'], equals(4000.0));
      expect(parsedRows[0]['dueAmount'], equals(4000.0));
      expect(parsedRows[0]['dueDate'], equals('2026-07-10'));

      // Row 2 (Sunshine Invoice 2 - continuation row): SUN-101, Sunshine Pharmacy (forward-filled)
      expect(parsedRows[1]['partyCode'], equals('SUN-101'));
      expect(parsedRows[1]['partyName'], equals('Sunshine Pharmacy'));
      expect(parsedRows[1]['salesman'], equals('Ravi'));
      expect(parsedRows[1]['transactionNumber'], equals('INV-SUN-02'));
      expect(parsedRows[1]['amount'], equals(3200.0));
      expect(parsedRows[1]['dueAmount'], equals(3200.0));
      expect(parsedRows[1]['dueDate'], equals('2026-07-12'));

      // Row 3 (Sunshine Invoice 3 - continuation row): SUN-101, Sunshine Pharmacy (forward-filled)
      expect(parsedRows[2]['partyCode'], equals('SUN-101'));
      expect(parsedRows[2]['partyName'], equals('Sunshine Pharmacy'));
      expect(parsedRows[2]['salesman'], equals('Ravi'));
      expect(parsedRows[2]['transactionNumber'], equals('INV-SUN-03'));
      expect(parsedRows[2]['amount'], equals(2000.0));
      expect(parsedRows[2]['dueAmount'], equals(2000.0));
      expect(parsedRows[2]['dueDate'], equals('2026-07-15'));

      // Row 4 (Green Leaf Invoice 1): GRN-202, Green Leaf
      expect(parsedRows[3]['partyCode'], equals('GRN-202'));
      expect(parsedRows[3]['partyName'], equals('Green Leaf'));
      expect(parsedRows[3]['salesman'], equals('Kumar'));
      expect(parsedRows[3]['transactionNumber'], equals('INV-GRN-01'));
      expect(parsedRows[3]['amount'], equals(2000.0));
      expect(parsedRows[3]['dueAmount'], equals(2000.0));
      expect(parsedRows[3]['dueDate'], equals('2026-07-20'));

      // Row 5 (Green Leaf Invoice 2): GRN-202, Green Leaf
      expect(parsedRows[4]['partyCode'], equals('GRN-202'));
      expect(parsedRows[4]['partyName'], equals('Green Leaf'));
      expect(parsedRows[4]['salesman'], equals('Kumar'));
      expect(parsedRows[4]['transactionNumber'], equals('INV-GRN-02'));
      expect(parsedRows[4]['amount'], equals(1500.0));
      expect(parsedRows[4]['dueAmount'], equals(1500.0));
      expect(parsedRows[4]['dueDate'], equals('2026-07-22'));
    });

    test('Flat-format regression Excel sheet parses correctly', () {
      final bytes = ExcelTestGenerator.generateTestExcelBytes();
      final results = parseExcelIsolate(bytes);

      final parsedRows = results['parsedRows'] as List<dynamic>;
      final skippedInvalidRows = results['skippedInvalidRows'] as int;

      // In the flat test:
      // Row 2: valid (Alpha Meds, INV-ABC-123)
      // Row 3: valid (Alpha Meds, INV-ABC-456)
      // Row 4: invalid (Beta Pharmacy, blank due date) -> skipped
      // Row 5: invalid (Gamma Clinic, unparseable amount) -> skipped
      // Row 6: valid (Delta Pharmacy, INV-GHI-888)
      // Total valid: 3, Total skipped: 2.
      expect(parsedRows.length, equals(3));
      expect(skippedInvalidRows, equals(2));

      expect(parsedRows[0]['partyCode'], equals('P-2001'));
      expect(parsedRows[0]['salesman'], isNull);
      expect(parsedRows[0]['transactionNumber'], equals('INV-ABC-123'));

      expect(parsedRows[1]['partyCode'], equals('P-2001'));
      expect(parsedRows[1]['salesman'], isNull);
      expect(parsedRows[1]['transactionNumber'], equals('INV-ABC-456'));

      expect(parsedRows[2]['partyCode'], equals('P-2004'));
      expect(parsedRows[2]['salesman'], isNull);
      expect(parsedRows[2]['transactionNumber'], equals('INV-GHI-888'));
    });
  });
}
