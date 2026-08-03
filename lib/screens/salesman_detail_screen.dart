import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pharmacy.dart';
import '../models/reminder.dart';
import '../data/pharmacy_repository.dart';
import '../data/reminder_repository.dart';
import '../services/formatters.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import 'call_dialog.dart';
import 'pharmacy_detail_screen.dart';

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
  List<Pharmacy> _pharmacies = [];
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

    final phList = await _pharmacyRepo.getPharmaciesBySalesman(widget.salesmanName);
    final history = await _reminderRepo.getBySalesman(widget.salesmanName);

    double sum = 0.0;
    for (final ph in phList) {
      sum += ph.totalAmount ?? 0.0;
    }

    if (mounted) {
      setState(() {
        _pharmacies = phList;
        _callHistory = history;
        _totalDues = sum;
        _isLoading = false;
      });
    }
  }

  void _openLogCallDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => LogRescheduleCallDialog(
        salesmanName: widget.salesmanName,
      ),
    ).then((_) => _loadData());
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.blue[800]!;
      case 'done':
        return Colors.green[800]!;
      case 'rescheduled':
        return Colors.orange[800]!;
      default:
        return Colors.grey[800]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardA = Colors.white.withValues(alpha: 0.95);
    const cardB = Color(0xFFE0F2F1);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF00695C),
        elevation: 1,
        shadowColor: Colors.black12,
        title: Text(
          widget.salesmanName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk, color: Color(0xFF00695C)),
            onPressed: _openLogCallDialog,
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.appBackground,
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00695C)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Summary Card
                      Card(
                        margin: EdgeInsets.zero,
                        color: cardA,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.teal[200]!, width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFFB2DFDB),
                                child: const Icon(
                                  Icons.person,
                                  size: 32,
                                  color: Color(0xFF004D40),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.salesmanName,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF004D40),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_pharmacies.length} Assigned Pharmacies',
                                      style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF00695C)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Total Dues: ${formatIndianCurrency(_totalDues)}',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF004D40),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Assigned Pharmacies List Section
                      Text(
                        'Assigned Pharmacies (${_pharmacies.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF004D40),
                        ),
                      ),
                      const SizedBox(height: 8),

                      _pharmacies.isEmpty
                          ? Card(
                              margin: EdgeInsets.zero,
                              color: cardA,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.teal[200]!, width: 1),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Center(
                                  child: Text(
                                    'No pharmacies assigned to this salesman.',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF00695C)),
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _pharmacies.length,
                              itemBuilder: (context, index) {
                                final ph = _pharmacies[index];
                                final total = ph.totalAmount ?? 0.0;
                                final cardBg = index.isEven ? cardA : cardB;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  color: cardBg,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: Colors.teal[200]!, width: 1),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => PharmacyDetailScreen(pharmacy: ph),
                                        ),
                                      ).then((_) => _loadData());
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  ph.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: Color(0xFF004D40),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Party Code: ${ph.partyCode}${ph.city != null && ph.city!.isNotEmpty ? ' | ${ph.city}' : ''}',
                                                  style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF00695C)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            formatIndianCurrency(total),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Color(0xFF004D40),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: 24),

                      // Call Log History Section
                      Text(
                        'Call Log History',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF004D40),
                        ),
                      ),
                      const SizedBox(height: 8),

                      _callHistory.isEmpty
                          ? Card(
                              margin: EdgeInsets.zero,
                              color: cardA,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.teal[200]!, width: 1),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Center(
                                  child: Text(
                                    'No call history recorded for this salesman.',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF00695C)),
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
                                final cardBg = index.isEven ? cardA : cardB;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  color: cardBg,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: Colors.teal[200]!, width: 1),
                                  ),
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
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF004D40),
                                              ),
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
                                            style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF00695C)),
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
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ElevatedButton.icon(
              onPressed: _openLogCallDialog,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: const Color(0xFF00695C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_call),
              label: const Text(
                'Log a Call with Salesman',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
