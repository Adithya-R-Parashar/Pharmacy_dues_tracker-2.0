class CategoryCalculator {
  /// Classifies a pharmacy's category (A-E) based on total outstanding amount,
  /// used only as a fallback when the Excel sheet doesn't provide a category directly.
  /// A: >= 100000, B: 50000-99999, C: 10000-49999, D: 5000-9999, E: < 5000.
  static String categoryForAmount(double? amount) {
    final a = amount ?? 0;
    if (a >= 100000) return 'A';
    if (a >= 50000) return 'B';
    if (a >= 10000) return 'C';
    if (a >= 5000) return 'D';
    return 'E';
  }
}
