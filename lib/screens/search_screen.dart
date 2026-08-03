import 'dart:async';
import 'package:flutter/material.dart';
import '../models/pharmacy.dart';
import '../models/reminder.dart';
import '../data/pharmacy_repository.dart';
import '../data/reminder_repository.dart';
import '../services/formatters.dart';
import '../theme.dart';
import 'pharmacy_detail_screen.dart';
import 'salesman_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final PharmacyRepository _pharmacyRepo = PharmacyRepository();
  final ReminderRepository _reminderRepo = ReminderRepository();

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // Search Results
  List<Pharmacy> _pharmacyResults = [];
  List<SalesmanSummary> _salesmanResults = [];
  final Map<int, Pharmacy> _pharmacyCache = {};

  // Dates Tab Selection
  DateTime _selectedDate = DateTime.now();
  List<Reminder> _dateRemindersScheduled = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadDateData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      _searchController.clear();
      setState(() {
        _pharmacyResults = [];
        _salesmanResults = [];
      });
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _pharmacyResults = [];
        _salesmanResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    if (_tabController.index == 0) {
      final results = await _pharmacyRepo.searchPharmacies(query);
      setState(() {
        _pharmacyResults = results;
        _isLoading = false;
      });
    } else if (_tabController.index == 2) {
      final results = await _pharmacyRepo.searchSalesmen(query);
      setState(() {
        _salesmanResults = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDateData() async {
    setState(() {
      _isLoading = true;
    });

    final dateStr = _formatDate(_selectedDate);
    final reminders = await _reminderRepo.getScheduledOn(dateStr);

    final ids = <int>{};
    for (final rem in reminders) {
      if (rem.reminderType == 'pharmacy' && rem.pharmacyId != null) {
        ids.add(rem.pharmacyId!);
      }
    }

    for (final id in ids) {
      if (!_pharmacyCache.containsKey(id)) {
        final ph = await _pharmacyRepo.getById(id);
        if (ph != null) {
          _pharmacyCache[id] = ph;
        }
      }
    }

    setState(() {
      _dateRemindersScheduled = reminders;
      _isLoading = false;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadDateData();
    }
  }

  void _setToday() {
    setState(() {
      _selectedDate = DateTime.now();
    });
    _loadDateData();
  }

  void _navigateToDetail(int pharmacyId) async {
    final ph = _pharmacyCache[pharmacyId] ?? await _pharmacyRepo.getById(pharmacyId);
    if (ph != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PharmacyDetailScreen(pharmacy: ph),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardA = Colors.white.withValues(alpha: 0.95);
    const cardB = Color(0xFFE0F2F1);

    String searchLabel = 'Search';
    if (_tabController.index == 0) {
      searchLabel = 'Search Pharmacies by Name or City';
    } else if (_tabController.index == 2) {
      searchLabel = 'Search Salesmen by Name or City';
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF00695C),
        elevation: 1,
        shadowColor: Colors.black12,
        title: const Text('Search'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF00695C),
          unselectedLabelColor: const Color(0xFF607D8B),
          indicatorColor: const Color(0xFF00695C),
          tabs: const [
            Tab(text: 'Pharmacies'),
            Tab(text: 'Dates'),
            Tab(text: 'Salesmen'),
          ],
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.appBackground,
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (_tabController.index != 1)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: Color(0xFF004D40)),
                    decoration: InputDecoration(
                      labelText: searchLabel,
                      labelStyle: const TextStyle(color: Color(0xFF00695C)),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF00695C)),
                      border: const OutlineInputBorder(),
                      fillColor: Colors.white.withValues(alpha: 0.95),
                      filled: true,
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Color(0xFF00695C)),
                              onPressed: () {
                                _searchController.clear();
                                _performSearch('');
                              },
                            )
                          : null,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF00695C)))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          // 1. Pharmacies Tab
                          _pharmacyResults.isEmpty
                              ? Center(
                                  child: Text(
                                    _searchController.text.isEmpty ? 'Type to search pharmacies' : 'No pharmacies found',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF004D40)),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  itemCount: _pharmacyResults.length,
                                  itemBuilder: (context, index) {
                                    final ph = _pharmacyResults[index];
                                    final cityText = ph.city != null && ph.city!.isNotEmpty ? ' | ${ph.city}' : '';
                                    final cardBg = index.isEven ? cardA : cardB;

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      color: cardBg,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(color: Colors.teal[200]!, width: 1),
                                      ),
                                      child: ListTile(
                                        title: Text(
                                          ph.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          'Party Code: ${ph.partyCode}$cityText',
                                          style: const TextStyle(color: Color(0xFF00695C)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: Text(
                                          formatIndianCurrency(ph.totalAmount ?? 0.0),
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                                        ),
                                        onTap: () {
                                          _pharmacyCache[ph.id!] = ph;
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => PharmacyDetailScreen(pharmacy: ph),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),

                          // 2. Dates Tab
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  alignment: WrapAlignment.start,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _selectDate,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF00695C),
                                        side: const BorderSide(color: Color(0xFF00695C)),
                                      ),
                                      icon: const Icon(Icons.calendar_today, color: Color(0xFF00695C)),
                                      label: Text(
                                        'Date: ${_formatDate(_selectedDate)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: _setToday,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF00695C),
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Today', maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                Text(
                                  'Calls Scheduled on Date',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF004D40),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _dateRemindersScheduled.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8.0),
                                        child: Text('No calls scheduled on this date.', style: TextStyle(color: Color(0xFF004D40))),
                                      )
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: _dateRemindersScheduled.length,
                                        itemBuilder: (context, index) {
                                          final rem = _dateRemindersScheduled[index];
                                          final isPharmacy = rem.reminderType == 'pharmacy';
                                          final phName = isPharmacy ? (_pharmacyCache[rem.pharmacyId]?.name ?? 'Pharmacy') : '';
                                          final timeStr = rem.scheduledTime != null ? ' at ${rem.scheduledTime}' : '';
                                          final cardBg = index.isEven ? cardA : cardB;

                                          return Card(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            color: cardBg,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                              side: BorderSide(color: Colors.teal[200]!, width: 1),
                                            ),
                                            child: ListTile(
                                              leading: Icon(
                                                isPharmacy ? Icons.local_pharmacy_outlined : Icons.badge_outlined,
                                                color: const Color(0xFF00695C),
                                              ),
                                              title: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      '${isPharmacy ? phName : rem.salesmanName!}$timeStr',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
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
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              subtitle: Text(
                                                rem.notes ?? 'No notes recorded',
                                                style: const TextStyle(color: Color(0xFF00695C)),
                                              ),
                                              trailing: const Icon(Icons.chevron_right, color: Color(0xFF004D40)),
                                              onTap: () {
                                                if (isPharmacy && rem.pharmacyId != null) {
                                                  _navigateToDetail(rem.pharmacyId!);
                                                } else if (!isPharmacy && rem.salesmanName != null) {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) => SalesmanDetailScreen(salesmanName: rem.salesmanName!),
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          );
                                        },
                                      ),
                              ],
                            ),
                          ),

                          // 3. Salesmen Tab
                          _salesmanResults.isEmpty
                              ? Center(
                                  child: Text(
                                    _searchController.text.isEmpty ? 'Type to search salesmen' : 'No salesmen found',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF004D40)),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  itemCount: _salesmanResults.length,
                                  itemBuilder: (context, index) {
                                    final summary = _salesmanResults[index];
                                    final cardBg = index.isEven ? cardA : cardB;

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      color: cardBg,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(color: Colors.teal[200]!, width: 1),
                                      ),
                                      child: ListTile(
                                        leading: const CircleAvatar(
                                          backgroundColor: Color(0xFFB2DFDB),
                                          child: Icon(Icons.person, color: Color(0xFF004D40)),
                                        ),
                                        title: Text(
                                          summary.salesman,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          '${summary.pharmacyCount} ${summary.pharmacyCount == 1 ? 'pharmacy' : 'pharmacies'}',
                                          style: const TextStyle(color: Color(0xFF00695C)),
                                        ),
                                        trailing: Text(
                                          formatIndianCurrency(summary.totalDue),
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                                        ),
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => SalesmanDetailScreen(salesmanName: summary.salesman),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
