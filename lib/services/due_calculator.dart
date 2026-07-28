enum UrgencyLevel {
  overdue, // past due date (daysUntil < 0)
  warning, // due within 3 days (0 <= daysUntil <= 3)
  normal,  // due in more than 3 days (daysUntil > 3)
}

class DueCalculator {
  /// Calculates calendar days until the target [date] string (format: yyyy-MM-dd).
  /// Returns a positive number if in the future, 0 if today, and negative if overdue (in the past).
  static int daysUntil(String date) {
    final targetDate = DateTime.parse(date);
    final targetNormalized = DateTime(targetDate.year, targetDate.month, targetDate.day);
    
    final now = DateTime.now();
    final nowNormalized = DateTime(now.year, now.month, now.day);
    
    return targetNormalized.difference(nowNormalized).inDays;
  }

  /// Evaluates the [UrgencyLevel] for a given [date] string (format: yyyy-MM-dd).
  static UrgencyLevel getUrgency(String date) {
    final days = daysUntil(date);
    if (days < 0) {
      return UrgencyLevel.overdue;
    } else if (days <= 3) {
      return UrgencyLevel.warning;
    } else {
      return UrgencyLevel.normal;
    }
  }
}
