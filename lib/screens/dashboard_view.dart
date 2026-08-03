import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'search_screen.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final PharmacyRepository _pharmacyRepo = PharmacyRepository();
  final ReminderRepository _reminderRepo = ReminderRepository();

  bool _isLoading = true;
  List<Reminder> _todayReminders = [];
  Map<int, Pharmacy> _pharmacyMap = {};
  Map<String, double> _salesmanDues = {};
  List<Pharmacy> _receivables = [];

  // Filter States
  String? _filterCity;
  String? _filterSalesman;
  String _sortOrder = 'DESC'; // 'DESC' = Highest to Lowest, 'ASC' = Lowest to Highest

  List<String> _citiesList = [];
  List<String> _salesmenList = [];

  bool get _hasFilters => _filterCity != null || _filterSalesman != null || _sortOrder != 'DESC';

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

    final reminders = await _reminderRepo.getScheduledOn(todayStr);
    final cities = await _pharmacyRepo.getDistinctCities();
    final summaries = await _pharmacyRepo.getSalesmenSummary();
    final salesmen = summaries.map((s) => s.salesman).toList();

    List<Pharmacy> list;
    if (_hasFilters) {
      list = await _pharmacyRepo.getFilteredPharmacies(
        city: _filterCity,
        salesman: _filterSalesman,
        sortOrder: _sortOrder,
      );
    } else {
      list = await _pharmacyRepo.getAll(sortOrder: _sortOrder);
    }

    final pMap = <int, Pharmacy>{};
    for (final ph in await _pharmacyRepo.getAll()) {
      if (ph.id != null) {
        pMap[ph.id!] = ph;
      }
    }

    final salesmanDuesMap = <String, double>{};
    for (final s in summaries) {
      salesmanDuesMap[s.salesman.toLowerCase().trim()] = s.totalDue;
    }

    if (mounted) {
      setState(() {
        _todayReminders = reminders;
        _pharmacyMap = pMap;
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String? tempCity = _filterCity;
        String? tempSalesman = _filterSalesman;
        String tempSortOrder = _sortOrder;

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
                          'Filters & Sorting',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF004D40),
                              ),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              tempCity = null;
                              tempSalesman = null;
                              tempSortOrder = 'DESC';
                            });
                          },
                          child: const Text('Clear All', style: TextStyle(color: Color(0xFF00695C))),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 12),

                    Text(
                      'City / Area',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF00695C),
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
                          child: Text(city, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setSheetState(() {
                          tempCity = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Salesman',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF00695C),
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
                          child: Text(salesman, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setSheetState(() {
                          tempSalesman = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Sort by Amount',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF00695C),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    // ignore: deprecated_member_use
                    RadioListTile<String>(
                      title: const Text('Highest to Lowest (Default)', style: TextStyle(fontSize: 14, color: Color(0xFF004D40))),
                      value: 'DESC',
                      // ignore: deprecated_member_use
                      groupValue: tempSortOrder,
                      activeColor: const Color(0xFF00695C),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      // ignore: deprecated_member_use
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() {
                            tempSortOrder = val;
                          });
                        }
                      },
                    ),
                    // ignore: deprecated_member_use
                    RadioListTile<String>(
                      title: const Text('Lowest to Highest', style: TextStyle(fontSize: 14, color: Color(0xFF004D40))),
                      value: 'ASC',
                      // ignore: deprecated_member_use
                      groupValue: tempSortOrder,
                      activeColor: const Color(0xFF00695C),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      // ignore: deprecated_member_use
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() {
                            tempSortOrder = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00695C),
                            side: const BorderSide(color: Color(0xFF00695C)),
                          ),
                          child: const Text('Cancel', maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _filterCity = tempCity;
                              _filterSalesman = tempSalesman;
                              _sortOrder = tempSortOrder;
                            });
                            _loadData();
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00695C),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Apply', maxLines: 1, overflow: TextOverflow.ellipsis),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardA = Colors.white.withValues(alpha: 0.95);
    const cardB = Color(0xFFE0F2F1); // Teal 50

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.appBackground,
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00695C)))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        systemOverlayStyle: const SystemUiOverlayStyle(
                          statusBarColor: Colors.white,
                          statusBarIconBrightness: Brightness.dark,
                          statusBarBrightness: Brightness.light,
                        ),
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF00695C),
                        elevation: 1,
                        shadowColor: Colors.black12,
                        title: Text(
                          'Pharmacy Dues Tracker',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF00695C),
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
                                  color: const Color(0xFF00695C),
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
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.search, color: Color(0xFF00695C)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Search pharmacies, dates, salesmen...',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: const Color(0xFF607D8B),
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
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      "Today's Call Reminders",
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF004D40),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => _openCallDialog(null, null, null),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text(
                                      'Schedule Call',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00695C),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _todayReminders.isEmpty
                                  ? Card(
                                      margin: EdgeInsets.zero,
                                      color: Colors.white.withValues(alpha: 0.95),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(color: Colors.teal[200]!, width: 1),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Center(
                                          child: Text(
                                            'No calls scheduled for today.',
                                            style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF00695C)),
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
                                        final pharmacy = isPharmacy ? _pharmacyMap[rem.pharmacyId] : null;
                                        final pharmacyName = pharmacy?.name ?? 'Unknown Pharmacy';
                                        final totalDue = isPharmacy
                                            ? (pharmacy?.totalAmount ?? 0.0)
                                            : (_salesmanDues[rem.salesmanName?.toLowerCase().trim()] ?? 0.0);
                                        final timeStr = rem.scheduledTime ?? 'Anytime';

                                        final cardBg = index.isEven ? cardA : cardB;

                                        return Card(
                                          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
                                          color: cardBg,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            side: BorderSide(color: Colors.teal[200]!, width: 1),
                                          ),
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
                                            borderRadius: BorderRadius.circular(16),
                                            child: Padding(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    isPharmacy ? Icons.local_pharmacy_outlined : Icons.badge_outlined,
                                                    color: const Color(0xFF00695C),
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
                                                                style: const TextStyle(
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 16,
                                                                  color: Color(0xFF004D40),
                                                                ),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
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
                                                          style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF00695C)),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.phone_in_talk, color: Color(0xFF00695C)),
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
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF004D40),
                            ),
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
                                if (_filterCity != null)
                                  Chip(
                                    label: Text('City: $_filterCity', overflow: TextOverflow.ellipsis),
                                    onDeleted: () {
                                      setState(() {
                                        _filterCity = null;
                                      });
                                      _loadData();
                                    },
                                  ),
                                if (_filterSalesman != null)
                                  Chip(
                                    label: Text('Rep: $_filterSalesman', overflow: TextOverflow.ellipsis),
                                    onDeleted: () {
                                      setState(() {
                                        _filterSalesman = null;
                                      });
                                      _loadData();
                                    },
                                  ),
                                if (_sortOrder != 'DESC')
                                  Chip(
                                    label: const Text('Sort: Lowest First'),
                                    onDeleted: () {
                                      setState(() {
                                        _sortOrder = 'DESC';
                                      });
                                      _loadData();
                                    },
                                  ),
                                ActionChip(
                                  avatar: const Icon(Icons.clear_all, size: 16),
                                  label: const Text('Clear All'),
                                  onPressed: () {
                                    setState(() {
                                      _filterCity = null;
                                      _filterSalesman = null;
                                      _sortOrder = 'DESC';
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
                                child: Center(
                                  child: Text(
                                    'No outstanding receivables.',
                                    style: TextStyle(color: Color(0xFF004D40)),
                                  ),
                                ),
                              ),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final ph = _receivables[index];
                                  final cardBg = index.isEven ? cardA : cardB;

                                  return Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
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
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        ph.name,
                                                        style: theme.textTheme.titleMedium?.copyWith(
                                                          fontWeight: FontWeight.bold,
                                                          color: const Color(0xFF004D40),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Party Code: ${ph.partyCode}${ph.city != null && ph.city!.isNotEmpty ? ' | ${ph.city}' : ''}',
                                                        style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF00695C)),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  formatIndianCurrency(ph.totalAmount ?? 0.0),
                                                  style: theme.textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(0xFF004D40),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (ph.notes != null && ph.notes!.trim().isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                ph.notes!.trim(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: const Color(0xFF00695C),
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                childCount: _receivables.length,
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
  }
}
