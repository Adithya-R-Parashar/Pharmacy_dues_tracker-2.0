import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pharmacy.dart';
import '../models/reminder.dart';
import '../data/pharmacy_repository.dart';
import '../data/invoice_repository.dart';
import '../data/reminder_repository.dart';
import '../services/due_calculator.dart';
import '../services/formatters.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import 'call_dialog.dart';
import 'pharmacy_detail_screen.dart';
import 'salesman_detail_screen.dart';

class CallsView extends StatefulWidget {
  const CallsView({super.key});

  @override
  State<CallsView> createState() => _CallsViewState();
}

class _CallsViewState extends State<CallsView> {
  final PharmacyRepository _pharmacyRepo = PharmacyRepository();
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  final ReminderRepository _reminderRepo = ReminderRepository();

  bool _isLoading = true;
  String _filterQuery = '';

  // Daily Queue Stats
  int _todayCount = 0;
  double _todayTotalDue = 0.0;

  // Reminders data
  List<Reminder> _allPending = [];
  Map<int, Pharmacy> _pharmacyCache = {};
  Map<int, double> _pharmacyDues = {};
  Map<int, UrgencyLevel> _pharmacyUrgency = {};
  Map<String, double> _salesmanDues = {};

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

    final todayStr = '${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    
    // 1. Fetch today's pending reminders for stats
    final todayReminders = await _reminderRepo.getScheduledOn(todayStr);
    _todayCount = todayReminders.length;

    // 2. Fetch all pending reminders
    final pendingList = await _reminderRepo.getAllPending();

    // 3. Populate info mapping
    final tempCache = <int, Pharmacy>{};
    final tempDues = <int, double>{};
    final tempUrgency = <int, UrgencyLevel>{};

    final allPharmacyIds = <int>{};
    for (final rem in pendingList) {
      if (rem.reminderType == 'pharmacy' && rem.pharmacyId != null) {
        allPharmacyIds.add(rem.pharmacyId!);
      }
    }
    for (final rem in todayReminders) {
      if (rem.reminderType == 'pharmacy' && rem.pharmacyId != null) {
        allPharmacyIds.add(rem.pharmacyId!);
      }
    }

    for (final id in allPharmacyIds) {
      final ph = await _pharmacyRepo.getById(id);
      if (ph != null) {
        tempCache[id] = ph;
        final due = await _invoiceRepo.getTotalDueForPharmacy(id);
        tempDues[id] = due;

        // Calculate pharmacy urgency level
        final openInvoices = await _invoiceRepo.getOpenByPharmacy(id);
        var highestUrgency = UrgencyLevel.normal;
        for (final inv in openInvoices) {
          final urgency = DueCalculator.getUrgency(inv.dueDate);
          if (urgency == UrgencyLevel.overdue) {
            highestUrgency = UrgencyLevel.overdue;
            break;
          } else if (urgency == UrgencyLevel.warning) {
            highestUrgency = UrgencyLevel.warning;
          }
        }
        tempUrgency[id] = highestUrgency;
      }
    }

    // Load salesman summaries for dues stats
    final salesmanSummaries = await _pharmacyRepo.getSalesmenSummary();
    final salesmanDuesMap = <String, double>{};
    for (final s in salesmanSummaries) {
      salesmanDuesMap[s.salesman.toLowerCase().trim()] = s.totalDue;
    }

    // Calculate sum of due amounts for today's pending reminders
    double sum = 0.0;
    final seenPharmacies = <int>{};
    final seenSalesmen = <String>{};
    for (final rem in todayReminders) {
      if (rem.reminderType == 'pharmacy' && rem.pharmacyId != null) {
        if (!seenPharmacies.contains(rem.pharmacyId)) {
          seenPharmacies.add(rem.pharmacyId!);
          sum += tempDues[rem.pharmacyId!] ?? 0.0;
        }
      } else if (rem.reminderType == 'salesman' && rem.salesmanName != null) {
        final sName = rem.salesmanName!.toLowerCase().trim();
        if (!seenSalesmen.contains(sName)) {
          seenSalesmen.add(sName);
          sum += salesmanDuesMap[sName] ?? 0.0;
        }
      }
    }
    _todayTotalDue = sum;

    if (mounted) {
      setState(() {
        _allPending = pendingList;
        _pharmacyCache = tempCache;
        _pharmacyDues = tempDues;
        _pharmacyUrgency = tempUrgency;
        _salesmanDues = salesmanDuesMap;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter reminders by pharmacy or salesman name
    final filteredReminders = _allPending.where((rem) {
      final name = rem.reminderType == 'pharmacy'
          ? (_pharmacyCache[rem.pharmacyId]?.name ?? '')
          : (rem.salesmanName ?? '');
      return name.toLowerCase().contains(_filterQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calls Queue'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // 1. Daily Queue Summary Card
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
                          "Today's Queue Summary",
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pending Calls',
                                    style: TextStyle(color: theme.colorScheme.onPrimary.withValues(alpha: 0.8), fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$_todayCount',
                                    style: theme.textTheme.headlineMedium?.copyWith(
                                      color: theme.colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Total Queue Outstanding',
                                    style: TextStyle(color: theme.colorScheme.onPrimary.withValues(alpha: 0.8), fontSize: 13),
                                    textAlign: TextAlign.right,
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      formatIndianCurrency(_todayTotalDue),
                                      style: theme.textTheme.headlineSmall?.copyWith(
                                        color: theme.colorScheme.onPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // 2. Filter Bar
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Filter by Name',
                      prefixIcon: Icon(Icons.filter_list),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _filterQuery = val.trim();
                      });
                    },
                  ),
                ),

                // 3. Reminders Queue List
                Expanded(
                  child: filteredReminders.isEmpty
                      ? Center(
                          child: Text(
                            _filterQuery.isEmpty ? 'No pending call reminders found.' : 'No matching calls.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filteredReminders.length,
                          itemBuilder: (context, index) {
                            final rem = filteredReminders[index];
                            final isPharmacy = rem.reminderType == 'pharmacy';
                            final pharmacy = isPharmacy ? _pharmacyCache[rem.pharmacyId] : null;
                            final totalDue = isPharmacy
                                ? (_pharmacyDues[rem.pharmacyId] ?? 0.0)
                                : (_salesmanDues[rem.salesmanName?.toLowerCase().trim()] ?? 0.0);
                            final urgency = isPharmacy
                                ? (_pharmacyUrgency[rem.pharmacyId] ?? UrgencyLevel.normal)
                                : UrgencyLevel.normal;

                            return ReminderQueueCard(
                              key: ValueKey(rem.id),
                              reminder: rem,
                              pharmacy: pharmacy,
                              totalDue: totalDue,
                              urgency: urgency,
                              onAction: _loadData,
                            );
                          },
                        ),
                ),
              ],
            ),
      ),
    );
  }
}

class ReminderQueueCard extends StatefulWidget {
  final Reminder reminder;
  final Pharmacy? pharmacy; // Nullable
  final double totalDue;
  final UrgencyLevel urgency;
  final VoidCallback onAction;

  const ReminderQueueCard({
    super.key,
    required this.reminder,
    this.pharmacy,
    required this.totalDue,
    required this.urgency,
    required this.onAction,
  });

  @override
  State<ReminderQueueCard> createState() => _ReminderQueueCardState();
}

class _ReminderQueueCardState extends State<ReminderQueueCard> {
  late TextEditingController _notesController;
  final ReminderRepository _reminderRepo = ReminderRepository();
  bool _isDirty = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.reminder.notes ?? '');
    _notesController.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(ReminderQueueCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reminder.notes != oldWidget.reminder.notes) {
      _notesController.removeListener(_onTextChanged);
      _notesController.text = widget.reminder.notes ?? '';
      _notesController.addListener(_onTextChanged);
      setState(() {
        _isDirty = false;
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final original = widget.reminder.notes ?? '';
    final current = _notesController.text;
    if ((original != current) != _isDirty) {
      setState(() {
        _isDirty = original != current;
      });
    }
  }

  Future<void> _saveNotes() async {
    if (!_isDirty) return;
    setState(() {
      _isSaving = true;
    });
    try {
      await _reminderRepo.updateNotes(widget.reminder.id!, _notesController.text.trim());
      setState(() {
        _isDirty = false;
      });
      widget.onAction();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note updated successfully'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save note: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _openCallDialog(Pharmacy? pharmacy, String? salesmanName, Reminder reminder) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => LogRescheduleCallDialog(
        pharmacy: pharmacy,
        salesmanName: salesmanName,
        reminder: reminder,
      ),
    ).then((_) {
      widget.onAction();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = widget.reminder.scheduledTime != null ? ' at ${widget.reminder.scheduledTime}' : '';
    final isPharmacy = widget.reminder.reminderType == 'pharmacy';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Target Name (underlined, navigate to detail) & Urgency Badge or Type Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPharmacy ? Icons.local_pharmacy_outlined : Icons.badge_outlined,
                            color: isPharmacy ? Colors.teal : Colors.indigo,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isPharmacy ? Colors.teal : Colors.indigo).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isPharmacy ? 'Pharmacy' : 'Salesman',
                              style: TextStyle(
                                color: isPharmacy ? Colors.teal : Colors.indigo,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () {
                            if (isPharmacy && widget.pharmacy != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PharmacyDetailScreen(pharmacy: widget.pharmacy!),
                                ),
                              ).then((_) => widget.onAction());
                            } else if (!isPharmacy && widget.reminder.salesmanName != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SalesmanDetailScreen(salesmanName: widget.reminder.salesmanName!),
                                ),
                              ).then((_) => widget.onAction());
                            }
                          },
                          child: Text(
                            isPharmacy ? (widget.pharmacy?.name ?? 'Unknown') : widget.reminder.salesmanName!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isPharmacy)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getUrgencyColor(context, widget.urgency).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _getUrgencyColor(context, widget.urgency),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _getUrgencyLabel(widget.urgency),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _getUrgencyColor(context, widget.urgency),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: Total Due & Scheduled Time
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Dues: ${formatIndianCurrency(widget.totalDue)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Schedule: ${widget.reminder.scheduledDate}$timeStr',
                  style: TextStyle(color: Colors.grey[750], fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 3: Inline Notes Editing Field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    maxLines: null,
                    minLines: 1,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _saveNotes(),
                  ),
                ),
                if (_isDirty) ...[
                  const SizedBox(width: 8),
                  _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.save, color: Colors.green),
                          onPressed: _saveNotes,
                          tooltip: 'Save Note',
                        ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),

            // Row 4: Action Buttons (Reschedule and Phone-call icon)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _openCallDialog(widget.pharmacy, widget.reminder.salesmanName, widget.reminder),
                  icon: const Icon(Icons.edit_calendar),
                  label: const Text('Reschedule'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _openCallDialog(widget.pharmacy, widget.reminder.salesmanName, widget.reminder),
                  icon: const Icon(Icons.phone_in_talk, color: Colors.blue),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
