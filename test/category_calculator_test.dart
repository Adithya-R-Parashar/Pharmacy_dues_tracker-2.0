import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_dues_tracker/services/category_calculator.dart';
import 'package:pharmacy_dues_tracker/models/voice_note.dart';

void main() {
  group('CategoryCalculator Unit Tests', () {
    test('Classifies total amounts correctly into A-E categories', () {
      expect(CategoryCalculator.categoryForAmount(150000.0), equals('A'));
      expect(CategoryCalculator.categoryForAmount(100000.0), equals('A'));
      expect(CategoryCalculator.categoryForAmount(75000.0), equals('B'));
      expect(CategoryCalculator.categoryForAmount(50000.0), equals('B'));
      expect(CategoryCalculator.categoryForAmount(25000.0), equals('C'));
      expect(CategoryCalculator.categoryForAmount(10000.0), equals('C'));
      expect(CategoryCalculator.categoryForAmount(7500.0), equals('D'));
      expect(CategoryCalculator.categoryForAmount(5000.0), equals('D'));
      expect(CategoryCalculator.categoryForAmount(3000.0), equals('E'));
      expect(CategoryCalculator.categoryForAmount(0.0), equals('E'));
      expect(CategoryCalculator.categoryForAmount(null), equals('E'));
    });
  });

  group('VoiceNote Model Unit Tests', () {
    test('VoiceNote toMap and fromMap serialization works', () {
      final note = VoiceNote(
        id: 1,
        pharmacyId: 42,
        filePath: '/path/to/voice.m4a',
        durationSeconds: 15,
        createdAt: '2026-08-13 10:00:00',
      );

      final map = note.toMap();
      final restored = VoiceNote.fromMap(map);

      expect(restored.id, equals(1));
      expect(restored.pharmacyId, equals(42));
      expect(restored.filePath, equals('/path/to/voice.m4a'));
      expect(restored.durationSeconds, equals(15));
      expect(restored.createdAt, equals('2026-08-13 10:00:00'));
    });
  });
}
