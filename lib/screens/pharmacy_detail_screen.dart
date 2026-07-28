import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pharmacy.dart';
import '../models/invoice.dart';
import '../models/reminder.dart';
import '../data/invoice_repository.dart';
import '../data/reminder_repository.dart';
import '../services/due_calculator.dart';
import '../services/formatters.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import 'call_dialog.dart';

class PharmacyDetailScreen extends StatefulWidget {
  final Pharmacy pharmacy;

  const PharmacyDetailScreen({
    super.key,
    required this.pharmacy,
  });

  @override
  State<PharmacyDetailScreen> createState() => _PharmacyDetailScreenState();
}

class _PharmacyDetailScreenState extends State<PharmacyDetailScreen> {
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  final ReminderRepository _reminderRepo = ReminderRepository();

  bool _isLoading = true;
  double _totalDue = 0.0;
  List<Invoice> _openInvoices = [];
  List<Reminder> _callHistory = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Provider.of<AppState>(context);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final pharmacyId = widget.pharmacy.id!;
    final due = await _invoiceRepo.getTotalDueForPharmacy(pharmacyId);
    final invoices = await _invoiceRepo.getOpenByPharmacy(pharmacyId);
    final history = await _reminderRepo.getByPharmacy(pharmacyId);

    if (mounted) {
      setState(() {
        _totalDue = due;
        _openInvoices = invoices;
        _callHistory = history;
        _isLoading = false;
      });
    }
  }

  void _openLogCallDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => LogRescheduleCallDialog(
        pharmacy: widget.pharmacy,
      ),
    );
  }

  Future<void> _confirmMarkPaid(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mark Invoice as Paid?'),
          content: Text(
            'Are you sure you want to mark invoice ${invoice.invoiceNumber} (outstanding: ${formatIndianCurrency(invoice.dueAmount)}) as fully paid?\n\nThis action is permanent.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Mark Paid'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _invoiceRepo.markAsPaid(invoice.id!);
      if (!mounted) return;
      Provider.of<AppState>(context, listen: false).refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice ${invoice.invoiceNumber} marked as paid')),
      );
      _loadData();
    }
  }

  Color _getUrgencyColor(BuildContext context, UrgencyLevel level) {
    final colors = Theme.of(context).extension<AppUrgencyColors>()!;
    switch (level) {
      case UrgencyLevel.overdue:
        return colors.urgentRed;
      case UrgencyLevel.warning:
        return colors.warningAmber;
      case UrgencyLevel.normal:
        return colors.neutral;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.blue;
      case 'done':
        return Colors.green;
      case 'rescheduled':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pharmacy.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk),
            onPressed: _openLogCallDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pharmacy Info Summary Card
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Outstanding',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                formatIndianCurrency(_totalDue),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),

                          Row(
                            children: [
                              Text(
                                'Party Code: ',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                              ),
                              Expanded(
                                child: Text(
                                  widget.pharmacy.partyCode,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Open Invoices: ',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                              ),
                              Expanded(
                                child: Text(
                                  '${_openInvoices.length}',
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (widget.pharmacy.salesman != null && widget.pharmacy.salesman!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Salesman: ',
                                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                                ),
                                Expanded(
                                  child: Text(
                                    widget.pharmacy.salesman!,
                                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (widget.pharmacy.city != null && widget.pharmacy.city!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'City: ',
                                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                                ),
                                Expanded(
                                  child: Text(
                                    widget.pharmacy.city!,
                                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Open Invoices Header
                  Text(
                    'Open Invoices',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  _openInvoices.isEmpty
                      ? Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(
                              child: Text(
                                'No open invoices.',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _openInvoices.length,
                          itemBuilder: (context, index) {
                            final inv = _openInvoices[index];
                            final urgency = DueCalculator.getUrgency(inv.dueDate);
                            final days = DueCalculator.daysUntil(inv.dueDate);
                            final color = _getUrgencyColor(context, urgency);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    InkWell(
                                      onTap: () => _confirmMarkPaid(inv),
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: theme.colorScheme.primary, width: 2),
                                        ),
                                        child: Icon(Icons.check, size: 20, color: theme.colorScheme.primary),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            inv.invoiceNumber,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Due: ${inv.dueDate}',
                                            style: TextStyle(color: Colors.grey[700], fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          formatIndianCurrency(inv.dueAmount),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: color, width: 1),
                                          ),
                                          child: Text(
                                            days < 0 ? '${days.abs()}d Overdue' : '$days d left',
                                            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 24),

                  // Call History Section Header
                  Text(
                    'Call Log History',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  _callHistory.isEmpty
                      ? Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(
                              child: Text(
                                'No call history recorded.',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _callHistory.length,
                          itemBuilder: (context, index) {
                            final rem = _callHistory[index];
                            final statusColor = _getStatusColor(rem.status);
                            final timeStr = rem.scheduledTime != null ? ' at ${rem.scheduledTime}' : '';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${rem.scheduledDate}$timeStr',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            rem.status.toUpperCase(),
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (rem.notes != null && rem.notes!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        rem.notes!,
                                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[800]),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ElevatedButton.icon(
            onPressed: _openLogCallDialog,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add_call),
            label: const Text(
              'Log a Call',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
