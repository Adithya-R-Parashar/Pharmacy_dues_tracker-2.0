import '../models/invoice.dart';
import 'database_helper.dart';

enum InvoiceUpsertResult {
  inserted,
  updated,
  skippedPaid,
}

class InvoiceRepository {
  String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dt) {
    final date = _formatDate(dt);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$date $h:$m:$s';
  }

  Future<List<Invoice>> getOpenByPharmacy(int pharmacyId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'invoices',
      where: 'pharmacy_id = ? AND status = ?',
      whereArgs: [pharmacyId, 'open'],
    );
    return maps.map((map) => Invoice.fromMap(map)).toList();
  }

  Future<List<Invoice>> getDueOn(String date) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'invoices',
      where: 'due_date = ? AND status = ?',
      whereArgs: [date, 'open'],
    );
    return maps.map((map) => Invoice.fromMap(map)).toList();
  }

  Future<List<Invoice>> searchByInvoiceNumber(String query) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.rawQuery(
      'SELECT * FROM invoices WHERE invoice_number LIKE ? COLLATE NOCASE',
      ['%$query%'],
    );
    return maps.map((map) => Invoice.fromMap(map)).toList();
  }

  Future<void> markAsPaid(int invoiceId) async {
    final db = await DatabaseHelper.instance.database;
    final today = _formatDate(DateTime.now());
    await db.update(
      'invoices',
      {
        'status': 'paid',
        'paid_date': today,
      },
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }

  Future<double> getTotalDueForPharmacy(int pharmacyId) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(due_amount) as total FROM invoices WHERE pharmacy_id = ? AND status = ?',
      [pharmacyId, 'open'],
    );
    if (result.isEmpty || result.first['total'] == null) {
      return 0.0;
    }
    return (result.first['total'] as num).toDouble();
  }

  Future<InvoiceUpsertResult> upsertFromImport({
    required String partyCode,
    required String invoiceNumber,
    String? invoiceDate,
    required double amount,
    required double dueAmount,
    required String dueDate,
  }) async {
    final db = await DatabaseHelper.instance.database;

    // Lookup pharmacy by party code
    final pharmacyMap = await db.query(
      'pharmacies',
      where: 'party_code = ?',
      whereArgs: [partyCode],
    );
    if (pharmacyMap.isEmpty) {
      throw Exception('Pharmacy with party code $partyCode not found.');
    }
    final pharmacyId = pharmacyMap.first['id'] as int;

    // Check if matching invoice already exists
    final existingInvoiceMaps = await db.query(
      'invoices',
      where: 'pharmacy_id = ? AND invoice_number = ?',
      whereArgs: [pharmacyId, invoiceNumber],
    );

    if (existingInvoiceMaps.isNotEmpty) {
      final existingInvoice = Invoice.fromMap(existingInvoiceMaps.first);
      if (existingInvoice.status == 'paid') {
        // Skip it entirely, do not overwrite paid invoices
        return InvoiceUpsertResult.skippedPaid;
      }
      // Update existing open invoice
      await db.update(
        'invoices',
        {
          'amount': amount,
          'due_amount': dueAmount,
          'due_date': dueDate,
        },
        where: 'id = ?',
        whereArgs: [existingInvoice.id],
      );
      return InvoiceUpsertResult.updated;
    } else {
      // Insert new open invoice
      final nowStr = _formatDateTime(DateTime.now());
      final newInvoice = Invoice(
        pharmacyId: pharmacyId,
        invoiceNumber: invoiceNumber,
        invoiceDate: invoiceDate,
        amount: amount,
        dueAmount: dueAmount,
        dueDate: dueDate,
        status: 'open',
        createdAt: nowStr,
      );
      await db.insert('invoices', newInvoice.toMap());
      return InvoiceUpsertResult.inserted;
    }
  }
}
