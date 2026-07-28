import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/pharmacy_repository.dart';
import '../data/reminder_repository.dart';
import '../models/reminder.dart';
import '../theme.dart';
import '../services/formatters.dart';
import '../services/due_calculator.dart';
import '../providers/app_state.dart';
import 'pharmacy_detail_screen.dart';
import 'call_dialog.dart';

class SalesmanDetailScreen extends StatefulWidget {
  final String salesmanName;

  const SalesmanDetailScreen({
    super.key,
    required this.salesmanName,
  });

  @override
  State<SalesmanDetailScreen> createState() => _SalesmanDetailScreenState();
}

class _SalesmanDetailScreenState extends State<SalesmanDetailScreen> {
  final PharmacyRepository _pharmacyRepo = PharmacyRepository();
  final ReminderRepository _reminderRepo = ReminderRepository();

  bool _isLoading = true;
  List<SalesmanPharmacyInfo> _pharmaciesInfo = [];
  List<Reminder> _callHistory = [];
  double _totalDues = 0.0;

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

    try {
      final list = await _pharmacyRepo.getPharmaciesBySalesman(widget.salesmanName);
      final history = await _reminderRepo.getBySalesman(widget.salesmanName);
      double total = 0.0;
      for (final info in list) {
        total += info.totalDue;
      }

      if (mounted) {
        setState(() {
          _pharmaciesInfo = list;
          _callHistory = history;
          _totalDues = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load salesman data: $e')),
        );
      }
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
        salesmanName: widget.salesmanName,
      ),
    ).then((_) {
      _loadData();
    });
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

  String _getUrgencyLabel(UrgencyLevel level) {
    switch (level) {
      case UrgencyLevel.overdue:
        return 'OVERDUE';
      case UrgencyLevel.warning:
        return 'DUE SOON';
      case UrgencyLevel.normal:
        return 'NORMAL';
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
        title: Text(widget.salesmanName),
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
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header details card
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sales Representative',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.salesmanName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  Text(
                                  'Pharmacies',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_pharmaciesInfo.length}',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Total Outstanding Dues',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatIndianCurrency(_totalDues),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Title: Assigned Pharmacies
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'Assigned Pharmacies',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Pharmacies List
                  _pharmaciesInfo.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text('No pharmacies assigned to this salesman.', style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _pharmaciesInfo.length,
                          itemBuilder: (context, index) {
                            final info = _pharmaciesInfo[index];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PharmacyDetailScreen(
                                        pharmacy: info.pharmacy,
                                      ),
                                    ),
                                  ).then((_) {
                                    _loadData();
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              info.pharmacy.name,
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '${info.openInvoiceCount} open ${info.openInvoiceCount == 1 ? "invoice" : "invoices"}',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: Colors.grey[650],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            formatIndianCurrency(info.totalDue),
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _getUrgencyColor(context, info.urgency).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: _getUrgencyColor(context, info.urgency),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              _getUrgencyLabel(info.urgency),
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: _getUrgencyColor(context, info.urgency),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                  const SizedBox(height: 16),

                  // Title: Call History
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'Call History',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Call History List
                  _callHistory.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text('No call history recorded.', style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _callHistory.length,
                          itemBuilder: (context, index) {
                            final rem = _callHistory[index];
                            final statusColor = _getStatusColor(rem.status);
                            final timeStr = rem.scheduledTime != null ? ' at ${rem.scheduledTime}' : '';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
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
