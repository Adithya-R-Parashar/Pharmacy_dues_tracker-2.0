class Invoice {
  final int? id;
  final int pharmacyId;
  final String invoiceNumber;
  final String? invoiceDate; // Format: yyyy-MM-dd, nullable
  final double amount;
  final double dueAmount;
  final String dueDate; // Format: yyyy-MM-dd
  final String status; // 'open' or 'paid'
  final String? paidDate; // Format: yyyy-MM-dd
  final String createdAt; // Format: yyyy-MM-dd HH:mm:ss

  Invoice({
    this.id,
    required this.pharmacyId,
    required this.invoiceNumber,
    this.invoiceDate,
    required this.amount,
    required this.dueAmount,
    required this.dueDate,
    required this.status,
    this.paidDate,
    required this.createdAt,
  });

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'] as int?,
      pharmacyId: map['pharmacy_id'] as int,
      invoiceNumber: map['invoice_number'] as String,
      invoiceDate: map['invoice_date'] as String?,
      amount: (map['amount'] as num).toDouble(),
      dueAmount: (map['due_amount'] as num).toDouble(),
      dueDate: map['due_date'] as String,
      status: map['status'] as String,
      paidDate: map['paid_date'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'pharmacy_id': pharmacyId,
      'invoice_number': invoiceNumber,
      'invoice_date': invoiceDate,
      'amount': amount,
      'due_amount': dueAmount,
      'due_date': dueDate,
      'status': status,
      'paid_date': paidDate,
      'created_at': createdAt,
    };
  }

  @override
  String toString() {
    return 'Invoice(id: $id, pharmacyId: $pharmacyId, invoiceNumber: $invoiceNumber, invoiceDate: $invoiceDate, amount: $amount, dueAmount: $dueAmount, dueDate: $dueDate, status: $status, paidDate: $paidDate, createdAt: $createdAt)';
  }
}
