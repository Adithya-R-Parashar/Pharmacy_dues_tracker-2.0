/// Formats a double amount into Indian currency format (e.g. ₹1,24,000 style).
String formatIndianCurrency(double amount) {
  final isNegative = amount < 0;
  final absVal = amount.abs();
  // Group digits using the Indian numbering system: 
  // Last three digits are grouped together, and then groupings of two.
  final fixedStr = absVal.toStringAsFixed(2);
  final parts = fixedStr.split('.');
  final whole = parts[0];
  final decimal = parts[1];

  if (whole.length <= 3) {
    final suffix = decimal == '00' ? '' : '.$decimal';
    return '${isNegative ? '-' : ''}₹$whole$suffix';
  }

  final lastThree = whole.substring(whole.length - 3);
  var remaining = whole.substring(0, whole.length - 3);
  final grouped = <String>[];
  while (remaining.length > 2) {
    grouped.insert(0, remaining.substring(remaining.length - 2));
    remaining = remaining.substring(0, remaining.length - 2);
  }
  if (remaining.isNotEmpty) {
    grouped.insert(0, remaining);
  }
  final wholeGrouped = '${grouped.join(",")},$lastThree';
  
  if (decimal == '00') {
    return '${isNegative ? '-' : ''}₹$wholeGrouped';
  } else {
    return '${isNegative ? '-' : ''}₹$wholeGrouped.$decimal';
  }
}
