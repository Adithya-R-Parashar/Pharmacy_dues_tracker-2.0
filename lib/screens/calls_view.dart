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
import 'salesman_detail_screen.dart';

class CallsView extends StatefulWidget {
  const CallsView({super.key});

  @override
  State<CallsView> createState() => _CallsViewState();
}

class _CallsViewState extends State<CallsView> {
  final PharmacyRepository _pharmacyRepo = PharmacyRepository();
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

    final todayReminders = await _reminderRepo.getScheduledOn(todayStr);
    _todayCount = todayReminders.length;

    final pendingList = await _reminderRepo.getAllPending();

    final tempCache = <int, Pharmacy>{};
    final tempDues = <int, double>{};

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
        tempDues[id] = ph.totalAmount ?? 0.0;
      }
    }

    final salesmanSummaries = await _pharmacyRepo.getSalesmenSummary();
    final salesmanDuesMap = <String, double>{};
    for (final s in salesmanSummaries) {
      salesmanDuesMap[s.salesman.toLowerCase().trim()] = s.totalDue;
    }

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
        _salesmanDues = salesmanDuesMap;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filteredReminders = _allPending.where((rem) {
      final name = rem.reminderType == 'pharmacy'
          ? (_pharmacyCache[rem.pharmacyId]?.name ?? '')
          : (rem.salesmanName ?? '');
      return name.toLowerCase().contains(_filterQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF00695C),
        elevation: 1,
        shadowColor: Colors.black12,
        title: const Text('Calls Queue'),
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
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF004D40), Color(0xFF00695C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
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
                              color: Colors.white,
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
                                    const Text(
                                      'Pending Calls',
                                      style: TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$_todayCount',
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        color: Colors.white,
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
                                    const Text(
                                      'Total Queue Outstanding',
                                      style: TextStyle(color: Colors.white70, fontSize: 13),
                                      textAlign: TextAlign.right,
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        formatIndianCurrency(_todayTotalDue),
                                        style: theme.textTheme.headlineSmall?.copyWith(
                                          color: Colors.white,
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

                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                    child: TextField(
                      style: const TextStyle(color: Color(0xFF004D40)),
                      decoration: InputDecoration(
                        labelText: 'Filter by Name',
                        labelStyle: const TextStyle(color: Color(0xFF00695C)),
                        prefixIcon: const Icon(Icons.filter_list, color: Color(0xFF00695C)),
                        border: const OutlineInputBorder(),
                        fillColor: Colors.white.withValues(alpha: 0.95),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _filterQuery = val.trim();
                        });
                      },
                    ),
                  ),

                  Expanded(
                    child: filteredReminders.isEmpty
                        ? Center(
                            child: Text(
                              _filterQuery.isEmpty ? 'No pending call reminders found.' : 'No matching calls.',
                              style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF004D40)),
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

                              return ReminderQueueCard(
                                key: ValueKey(rem.id),
                                reminder: rem,
                                pharmacy: pharmacy,
                                totalDue: totalDue,
                                itemIndex: index,
                                onAction: _loadData,
                              );
                            },
                          ),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}

class ReminderQueueCard extends StatefulWidget {
  final Reminder reminder;
  final Pharmacy? pharmacy;
  final double totalDue;
  final int itemIndex;
  final VoidCallback onAction;

  const ReminderQueueCard({
    super.key,
    required this.reminder,
    this.pharmacy,
    required this.totalDue,
    required this.itemIndex,
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = widget.reminder.scheduledTime != null ? ' at ${widget.reminder.scheduledTime}' : '';
    final isPharmacy = widget.reminder.reminderType == 'pharmacy';

    final cardA = Colors.white.withValues(alpha: 0.95);
    const cardB = Color(0xFFE0F2F1); // Teal 50
    final cardBg = widget.itemIndex.isEven ? cardA : cardB;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPharmacy ? Icons.local_pharmacy_outlined : Icons.badge_outlined,
                            color: const Color(0xFF00695C),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00695C).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isPharmacy ? 'Pharmacy' : 'Salesman',
                              style: const TextStyle(
                                color: Color(0xFF004D40),
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
                              color: const Color(0xFF004D40),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Dues: ${formatIndianCurrency(widget.totalDue)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Schedule: ${widget.reminder.scheduledDate}$timeStr',
                  style: const TextStyle(color: Color(0xFF00695C), fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _notesController,
                    style: const TextStyle(color: Color(0xFF004D40)),
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

            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _openCallDialog(widget.pharmacy, widget.reminder.salesmanName, widget.reminder),
                  icon: const Icon(Icons.edit_calendar, color: Color(0xFF00695C)),
                  label: const Text('Reschedule', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFF00695C))),
                ),
                IconButton(
                  onPressed: () => _openCallDialog(widget.pharmacy, widget.reminder.salesmanName, widget.reminder),
                  icon: const Icon(Icons.phone_in_talk, color: Color(0xFF00695C)),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF00695C).withValues(alpha: 0.1),
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
