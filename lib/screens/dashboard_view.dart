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
import 'search_screen.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final PharmacyRepository _pharmacyRepo = PharmacyRepository();
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  final _reminderRepo = ReminderRepository();

  bool _isLoading = true;
  List<Reminder> _todayReminders = [];
  Map<int, double> _pharmacyDues = {};
  Map<int, String> _pharmacyNames = {};
  Map<String, double> _salesmanDues = {};
  List<Map<String, dynamic>> _receivables = [];

  // Filter States
  DateTime? _filterDate;
  String? _filterCity;
  String? _filterSalesman;

  List<String> _citiesList = [];
  List<String> _salesmenList = [];

  bool get _hasFilters => _filterDate != null || _filterCity != null || _filterSalesman != null;

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
    
    // 1. Load today's call reminders
    final reminders = await _reminderRepo.getScheduledOn(todayStr);

    // 2. Fetch distinct cities and salesmen to keep filter dropdown lists loaded/up-to-date
    final cities = await _pharmacyRepo.getDistinctCities();
    final summaries = await _pharmacyRepo.getSalesmenSummary();
    final salesmen = summaries.map((s) => s.salesman).toList();

    // 3. Load pharmacies (filtered or all)
    final list = <Map<String, dynamic>>[];
    final duesMap = <int, double>{};
    final namesMap = <int, String>{};

    if (_hasFilters) {
      final String? filterDateStr = _filterDate != null
          ? '${_filterDate!.year.toString().padLeft(4, '0')}-${_filterDate!.month.toString().padLeft(2, '0')}-${_filterDate!.day.toString().padLeft(2, '0')}'
          : null;
      final filteredList = await _pharmacyRepo.getFilteredPharmacies(
        city: _filterCity,
        salesman: _filterSalesman,
        dueOnDate: filterDateStr,
      );

      for (final info in filteredList) {
        namesMap[info.pharmacy.id!] = info.pharmacy.name;
        duesMap[info.pharmacy.id!] = info.totalDue;
        list.add({
          'pharmacy': info.pharmacy,
          'due': info.totalDue,
          'urgency': info.urgency,
        });
      }
    } else {
      final pharmacies = await _pharmacyRepo.getAll();
      for (final ph in pharmacies) {
        namesMap[ph.id!] = ph.name;
        final due = await _invoiceRepo.getTotalDueForPharmacy(ph.id!);
        duesMap[ph.id!] = due;

        // Determine pharmacy urgency level
        final openInvoices = await _invoiceRepo.getOpenByPharmacy(ph.id!);
        var highestUrgency = UrgencyLevel.normal;
        for (final inv in openInvoices) {
          final urgency = DueCalculator.getUrgency(inv.dueDate);
          if (urgency == UrgencyLevel.overdue) {
            highestUrgency = UrgencyLevel.overdue;
            break; // Overdue is highest, no need to check further
          } else if (urgency == UrgencyLevel.warning) {
            highestUrgency = UrgencyLevel.warning;
          }
        }

        list.add({
          'pharmacy': ph,
          'due': due,
          'urgency': highestUrgency,
        });
      }
    }

    // Sort receivables: most urgent first (overdue > warning > normal), then total due descending
    list.sort((a, b) {
      final uA = a['urgency'] as UrgencyLevel;
      final uB = b['urgency'] as UrgencyLevel;
      if (uA != uB) {
        return uA.index.compareTo(uB.index); // overdue = index 0, warning = index 1, normal = index 2
      }
      final dA = a['due'] as double;
      final dB = b['due'] as double;
      return dB.compareTo(dA);
    });

    // 4. Fetch salesman dues map
    final salesmanDuesMap = <String, double>{};
    for (final s in summaries) {
      salesmanDuesMap[s.salesman.toLowerCase().trim()] = s.totalDue;
    }

    if (mounted) {
      setState(() {
        _todayReminders = reminders;
        _pharmacyDues = duesMap;
        _pharmacyNames = namesMap;
        _salesmanDues = salesmanDuesMap;
        _receivables = list;
        _citiesList = cities;
        _salesmenList = salesmen;
        _isLoading = false;
      });
    }
  }

  void _openCallDialog(Pharmacy? pharmacy, String? salesmanName, Reminder? reminder) {
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
    ).then((_) => _loadData());
  }

  void _openFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        DateTime? tempDate = _filterDate;
        String? tempCity = _filterCity;
        String? tempSalesman = _filterSalesman;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
            final paddingBottom = MediaQuery.of(context).padding.bottom;
            final effectiveBottomPadding = (viewInsetsBottom > paddingBottom ? viewInsetsBottom : paddingBottom) + 24.0;

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 16.0,
                  bottom: effectiveBottomPadding,
                ),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filters',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            tempDate = null;
                            tempCity = null;
                            tempSalesman = null;
                          });
                        },
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Date Picker Filter
                  Text(
                    'Due Date',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (tempDate != null)
                        InputChip(
                          label: Text(_formatDate(tempDate!)),
                          onDeleted: () {
                            setSheetState(() {
                              tempDate = null;
                            });
                          },
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                            );
                            if (picked != null) {
                              setSheetState(() {
                                tempDate = picked;
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: const Text('Pick Due Date'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // City/Area Dropdown
                  Text(
                    'City / Area',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: tempCity,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    hint: const Text('All Cities / Areas'),
                    items: _citiesList.map((city) {
                      return DropdownMenuItem<String>(
                        value: city,
                        child: Text(city),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setSheetState(() {
                        tempCity = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Salesman Dropdown
                  Text(
                    'Salesman',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: tempSalesman,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    hint: const Text('All Salesmen'),
                    items: _salesmenList.map((salesman) {
                      return DropdownMenuItem<String>(
                        value: salesman,
                        child: Text(salesman),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setSheetState(() {
                        tempSalesman = val;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Apply & Cancel buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _filterDate = tempDate;
                              _filterCity = tempCity;
                              _filterSalesman = tempSalesman;
                            });
                            _loadData();
                            Navigator.of(context).pop();
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
          },
        );
      },
    );
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

  String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: CustomScrollView(
                  slivers: [
                    // App Bar with Title, Filter, & Search Bar Below It
                    SliverAppBar(
                      title: Text(
                        'Pharmacy Dues Tracker',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      floating: false,
                      pinned: true,
                    actions: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              _hasFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                              color: _hasFilters ? theme.colorScheme.primary : null,
                            ),
                            onPressed: _openFilterBottomSheet,
                          ),
                          if (_hasFilters)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 8,
                                  minHeight: 8,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(48),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SearchScreen()),
                            );
                          },
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: theme.colorScheme.outlineVariant),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Search pharmacies, dates, invoices...',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Today's Call Reminders Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  "Today's Call Reminders",
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _openCallDialog(null, null, null),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Schedule Call'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _todayReminders.isEmpty
                              ? Card(
                                  margin: EdgeInsets.zero,
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Center(
                                      child: Text(
                                        'No calls scheduled for today.',
                                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: _todayReminders.length,
                                  itemBuilder: (context, index) {
                                    final rem = _todayReminders[index];
                                    final isPharmacy = rem.reminderType == 'pharmacy';
                                    final pharmacyName = isPharmacy ? (_pharmacyNames[rem.pharmacyId] ?? 'Unknown Pharmacy') : '';
                                    final totalDue = isPharmacy
                                        ? (_pharmacyDues[rem.pharmacyId] ?? 0.0)
                                        : (_salesmanDues[rem.salesmanName?.toLowerCase().trim()] ?? 0.0);
                                    final timeStr = rem.scheduledTime ?? 'Anytime';

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: InkWell(
                                        onTap: () async {
                                          final navigator = Navigator.of(context);
                                          if (isPharmacy) {
                                            final phs = await _pharmacyRepo.getById(rem.pharmacyId!);
                                            if (phs != null) {
                                              navigator.push(
                                                MaterialPageRoute(
                                                  builder: (_) => PharmacyDetailScreen(pharmacy: phs),
                                                ),
                                              ).then((_) => _loadData());
                                            }
                                          } else {
                                            if (rem.salesmanName != null) {
                                              navigator.push(
                                                MaterialPageRoute(
                                                  builder: (_) => SalesmanDetailScreen(salesmanName: rem.salesmanName!),
                                                ),
                                              ).then((_) => _loadData());
                                            }
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isPharmacy ? Icons.local_pharmacy_outlined : Icons.badge_outlined,
                                                color: isPharmacy ? Colors.teal : Colors.indigo,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            isPharmacy ? pharmacyName : rem.salesmanName!,
                                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
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
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Time: $timeStr | Total Due: ${formatIndianCurrency(totalDue)}',
                                                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.phone_in_talk, color: Colors.blue),
                                                onPressed: () async {
                                                  if (isPharmacy) {
                                                    final phs = await _pharmacyRepo.getById(rem.pharmacyId!);
                                                    if (phs != null) {
                                                      _openCallDialog(phs, null, rem);
                                                    }
                                                  } else {
                                                    _openCallDialog(null, rem.salesmanName, rem);
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),

                  // Outstanding Receivables Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        "Outstanding Receivables",
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // Active Filter Chips
                  if (_hasFilters)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (_filterDate != null)
                              Chip(
                                label: Text('Due: ${_formatDate(_filterDate!)}'),
                                onDeleted: () {
                                  setState(() {
                                    _filterDate = null;
                                  });
                                  _loadData();
                                },
                              ),
                            if (_filterCity != null)
                              Chip(
                                label: Text('City: $_filterCity'),
                                onDeleted: () {
                                  setState(() {
                                    _filterCity = null;
                                  });
                                  _loadData();
                                },
                              ),
                            if (_filterSalesman != null)
                              Chip(
                                label: Text('Rep: $_filterSalesman'),
                                onDeleted: () {
                                  setState(() {
                                    _filterSalesman = null;
                                  });
                                  _loadData();
                                },
                              ),
                            ActionChip(
                              avatar: const Icon(Icons.clear_all, size: 16),
                              label: const Text('Clear All'),
                              onPressed: () {
                                setState(() {
                                  _filterDate = null;
                                  _filterCity = null;
                                  _filterSalesman = null;
                                });
                                _loadData();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Outstanding Receivables List
                  _receivables.isEmpty
                      ? const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(child: Text('No outstanding receivables.')),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = _receivables[index];
                              final Pharmacy ph = item['pharmacy'];
                              final double due = item['due'];
                              final UrgencyLevel urgency = item['urgency'];

                              return Card(
                                margin: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PharmacyDetailScreen(pharmacy: ph),
                                      ),
                                    );
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
                                                ph.name,
                                                style: theme.textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Party Code: ${ph.partyCode}${ph.city != null && ph.city!.isNotEmpty ? ' | ${ph.city}' : ''}',
                                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              formatIndianCurrency(due),
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _getUrgencyColor(context, urgency).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: _getUrgencyColor(context, urgency),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                _getUrgencyLabel(urgency),
                                                style: theme.textTheme.labelSmall?.copyWith(
                                                  color: _getUrgencyColor(context, urgency),
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
                            childCount: _receivables.length,
                          ),
                        ),
                  
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 80),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
