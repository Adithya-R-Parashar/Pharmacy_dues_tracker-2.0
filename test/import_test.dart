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

      expect(parsedRows.length, equals(2));
      expect(skippedInvalidRows, equals(0));

      expect(parsedRows[0]['partyCode'], equals('SUN-101'));
      expect(parsedRows[0]['partyName'], equals('Sunshine Pharmacy'));
      expect(parsedRows[0]['salesman'], equals('Ravi'));
      expect(parsedRows[0]['city'], equals('Mumbai'));
      expect(parsedRows[0]['totalAmount'], equals(9200.0));
      expect(parsedRows[0]['bucket121180'], equals(4000.0));
      expect(parsedRows[0]['bucket181270'], equals(3200.0));
      expect(parsedRows[0]['bucket271360'], equals(2000.0));

      expect(parsedRows[1]['partyCode'], equals('GRN-202'));
      expect(parsedRows[1]['partyName'], equals('Green Leaf'));
      expect(parsedRows[1]['salesman'], equals('Kumar'));
      expect(parsedRows[1]['city'], equals('Pune'));
      expect(parsedRows[1]['totalAmount'], equals(3500.0));
      expect(parsedRows[1]['bucket121180'], equals(2000.0));
      expect(parsedRows[1]['bucket181270'], equals(1500.0));
    });

    test('Flat-format regression Excel sheet parses correctly', () {
      final bytes = ExcelTestGenerator.generateTestExcelBytes();
      final results = parseExcelIsolate(bytes);

      final parsedRows = results['parsedRows'] as List<dynamic>;
      final skippedInvalidRows = results['skippedInvalidRows'] as int;

      expect(parsedRows.length, equals(2));
      expect(skippedInvalidRows, equals(2));

      expect(parsedRows[0]['partyCode'], equals('P-2001'));
      expect(parsedRows[0]['totalAmount'], equals(2000.0));

      expect(parsedRows[1]['partyCode'], equals('P-2004'));
      expect(parsedRows[1]['totalAmount'], equals(4000.0));
    });
  });
}
