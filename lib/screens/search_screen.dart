import 'dart:async';
import 'package:flutter/material.dart';
import '../models/pharmacy.dart';
import '../models/invoice.dart';
import '../models/reminder.dart';
import '../data/pharmacy_repository.dart';
import '../data/invoice_repository.dart';
import '../data/reminder_repository.dart';
import '../services/formatters.dart';
import 'pharmacy_detail_screen.dart';
import 'salesman_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final PharmacyRepository _pharmacyRepo = PharmacyRepository();
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  final ReminderRepository _reminderRepo = ReminderRepository();

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // Search Results
  List<Pharmacy> _pharmacyResults = [];
  List<Invoice> _transactionResults = [];
  List<SalesmanSummary> _salesmanResults = [];
  final Map<int, Pharmacy> _pharmacyCache = {}; // Cache to look up pharmacy details quickly

  // Dates Tab Selection
  DateTime _selectedDate = DateTime.now();
  List<Invoice> _dateInvoicesDue = [];
  List<Reminder> _dateRemindersScheduled = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        _transactionResults = [];
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
        _transactionResults = [];
        _salesmanResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    if (_tabController.index == 0) {
      // Pharmacies Tab
      final results = await _pharmacyRepo.searchPharmacies(query);
      setState(() {
        _pharmacyResults = results;
        _isLoading = false;
      });
    } else if (_tabController.index == 2) {
      // Transactions Tab
      final results = await _invoiceRepo.searchByInvoiceNumber(query);
      // Fetch associated pharmacy details
      for (final inv in results) {
        if (!_pharmacyCache.containsKey(inv.pharmacyId)) {
          final ph = await _pharmacyRepo.getById(inv.pharmacyId);
          if (ph != null) {
            _pharmacyCache[inv.pharmacyId] = ph;
          }
        }
      }
      setState(() {
        _transactionResults = results;
        _isLoading = false;
      });
    } else if (_tabController.index == 3) {
      // Salesmen Tab
      final results = await _pharmacyRepo.searchSalesmen(query);
      setState(() {
        _salesmanResults = results;
        _isLoading = false;
      });
    }
  }

  // Dates Tab Actions
  Future<void> _loadDateData() async {
    setState(() {
      _isLoading = true;
    });

    final dateStr = _formatDate(_selectedDate);
    final invoices = await _invoiceRepo.getDueOn(dateStr);
    final reminders = await _reminderRepo.getScheduledOn(dateStr);

    // Cache pharmacy details
    final ids = <int>{};
    for (final inv in invoices) {
      ids.add(inv.pharmacyId);
    }
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
      _dateInvoicesDue = invoices;
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

    // Dynamic search label depending on active tab
    String searchLabel = 'Search';
    if (_tabController.index == 0) {
      searchLabel = 'Search Pharmacies by Name or City';
    } else if (_tabController.index == 2) {
      searchLabel = 'Search Invoices by Number';
    } else if (_tabController.index == 3) {
      searchLabel = 'Search Salesmen by Name or City';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pharmacies'),
            Tab(text: 'Dates'),
            Tab(text: 'Transactions'),
            Tab(text: 'Salesmen'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
        children: [
          // Render search field only for Pharmacy, Transaction, and Salesmen tabs
          if (_tabController.index != 1)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: searchLabel,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
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
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // 1. Pharmacies Tab
                      _pharmacyResults.isEmpty
                          ? Center(
                              child: Text(
                                _searchController.text.isEmpty ? 'Type to search pharmacies' : 'No pharmacies found',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _pharmacyResults.length,
                              itemBuilder: (context, index) {
                                final ph = _pharmacyResults[index];
                                final cityText = ph.city != null && ph.city!.isNotEmpty ? ' | ${ph.city}' : '';
                                return ListTile(
                                  title: Text(ph.name),
                                  subtitle: Text('Party Code: ${ph.partyCode}$cityText'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    _pharmacyCache[ph.id!] = ph;
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PharmacyDetailScreen(pharmacy: ph),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),

                      // 2. Dates Tab
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _selectDate,
                                    icon: const Icon(Icons.calendar_today),
                                    label: Text('Date: ${_formatDate(_selectedDate)}'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _setToday,
                                  child: const Text('Today'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            Text(
                              'Invoices Due on Date',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            _dateInvoicesDue.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8.0),
                                    child: Text('No invoices due on this date.', style: TextStyle(color: Colors.grey)),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _dateInvoicesDue.length,
                                    itemBuilder: (context, index) {
                                      final inv = _dateInvoicesDue[index];
                                      final phName = _pharmacyCache[inv.pharmacyId]?.name ?? 'Pharmacy';

                                      return Card(
                                        child: ListTile(
                                          title: Text('$phName - ${inv.invoiceNumber}'),
                                          subtitle: Text('Due Amount: ${formatIndianCurrency(inv.dueAmount)}'),
                                          trailing: const Icon(Icons.chevron_right),
                                          onTap: () => _navigateToDetail(inv.pharmacyId),
                                        ),
                                      );
                                    },
                                  ),
                            const SizedBox(height: 24),

                            Text(
                              'Calls Scheduled on Date',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            _dateRemindersScheduled.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8.0),
                                    child: Text('No calls scheduled on this date.', style: TextStyle(color: Colors.grey)),
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

                                      return Card(
                                        child: ListTile(
                                          leading: Icon(
                                            isPharmacy ? Icons.local_pharmacy_outlined : Icons.badge_outlined,
                                            color: isPharmacy ? Colors.teal : Colors.indigo,
                                          ),
                                          title: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${isPharmacy ? phName : rem.salesmanName!}$timeStr',
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          subtitle: Text(rem.notes ?? 'No notes recorded'),
                                          trailing: const Icon(Icons.chevron_right),
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

                      // 3. Transactions Tab
                      _transactionResults.isEmpty
                          ? Center(
                              child: Text(
                                _searchController.text.isEmpty ? 'Type to search invoices' : 'No invoices found',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _transactionResults.length,
                              itemBuilder: (context, index) {
                                final inv = _transactionResults[index];
                                final ph = _pharmacyCache[inv.pharmacyId];
                                final phName = ph?.name ?? 'Pharmacy';

                                return ListTile(
                                  title: Text('${inv.invoiceNumber} (${formatIndianCurrency(inv.dueAmount)})'),
                                  subtitle: Text('Pharmacy: $phName | Due: ${inv.dueDate} | Status: ${inv.status}'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _navigateToDetail(inv.pharmacyId),
                                );
                              },
                            ),

                      // 4. Salesmen Tab
                      _salesmanResults.isEmpty
                          ? Center(
                              child: Text(
                                _searchController.text.isEmpty ? 'Type to search salesmen' : 'No salesmen found',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _salesmanResults.length,
                              itemBuilder: (context, index) {
                                final summary = _salesmanResults[index];
                                return ListTile(
                                  leading: const Icon(Icons.person),
                                  title: Text(summary.salesman),
                                  subtitle: Text('${summary.pharmacyCount} ${summary.pharmacyCount == 1 ? 'pharmacy' : 'pharmacies'}'),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        formatIndianCurrency(summary.totalDue),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const Text('Dues', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => SalesmanDetailScreen(salesmanName: summary.salesman),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
  }
}
