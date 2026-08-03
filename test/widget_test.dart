import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_dues_tracker/services/excel_import_service.dart';
import 'package:pharmacy_dues_tracker/services/excel_test_generator.dart';

void main() {
  test('Smoke test for Excel generator and parser', () {
    final bytes = ExcelTestGenerator.generateGroupedExcelBytes();
    final results = parseExcelIsolate(bytes);
    final parsedRows = results['parsedRows'] as List<dynamic>;
    expect(parsedRows.isNotEmpty, isTrue);
  });
}
