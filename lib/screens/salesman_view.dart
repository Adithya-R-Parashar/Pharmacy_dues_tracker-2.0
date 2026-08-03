import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/pharmacy_repository.dart';
import '../services/formatters.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import 'salesman_detail_screen.dart';

class SalesmanView extends StatefulWidget {
  const SalesmanView({super.key});

  @override
  State<SalesmanView> createState() => _SalesmanViewState();
}

class _SalesmanViewState extends State<SalesmanView> {
  final PharmacyRepository _pharmacyRepo = PharmacyRepository();
  bool _isLoading = true;
  List<SalesmanSummary> _summaries = [];
  String _filterQuery = '';
  String? _selectedCity;
  List<String> _citiesList = [];
  Timer? _debounce;

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

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final cities = await _pharmacyRepo.getDistinctCities();
      await _fetchSalesmen();
      if (mounted) {
        setState(() {
          _citiesList = cities;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load salesmen summaries: $e')),
        );
      }
    }
  }

  Future<void> _fetchSalesmen() async {
    final list = _filterQuery.isEmpty
        ? await _pharmacyRepo.getSalesmenSummary(city: _selectedCity)
        : await _pharmacyRepo.searchSalesmen(_filterQuery, city: _selectedCity);
    if (mounted) {
      setState(() {
        _summaries = list;
      });
    }
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _filterQuery = val.trim();
      });
      _fetchSalesmen();
    });
  }

  void _openFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String? tempCity = _selectedCity;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
            final paddingBottom = MediaQuery.of(context).padding.bottom;
            final effectiveBottomPadding = (viewInsetsBottom > paddingBottom ? viewInsetsBottom : paddingBottom) + 16.0;

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
                          'Filter by City',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF004D40),
                              ),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              tempCity = null;
                            });
                          },
                          child: const Text('Clear Filter', style: TextStyle(color: Color(0xFF00695C))),
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
                              _selectedCity = tempCity;
                            });
                            _fetchSalesmen();
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
    const cardB = Color(0xFFE0F2F1);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF00695C),
        elevation: 1,
        shadowColor: Colors.black12,
        title: const Text('Sales Representatives'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  _selectedCity != null ? Icons.filter_alt : Icons.filter_alt_outlined,
                  color: const Color(0xFF00695C),
                ),
                onPressed: _openFilterBottomSheet,
              ),
              if (_selectedCity != null)
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
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        style: const TextStyle(color: Color(0xFF004D40)),
                        decoration: InputDecoration(
                          labelText: 'Search Salesmen by Name or City',
                          labelStyle: const TextStyle(color: Color(0xFF00695C)),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF00695C)),
                          border: const OutlineInputBorder(),
                          fillColor: Colors.white.withValues(alpha: 0.95),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),

                    if (_selectedCity != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(
                            label: Text('City: $_selectedCity', overflow: TextOverflow.ellipsis),
                            onDeleted: () {
                              setState(() {
                                _selectedCity = null;
                              });
                              _fetchSalesmen();
                            },
                          ),
                        ),
                      ),

                    Expanded(
                      child: _summaries.isEmpty
                          ? Center(
                              child: Text(
                                _filterQuery.isEmpty
                                    ? 'No salesmen assigned yet.'
                                    : 'No matching salesmen.',
                                style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF004D40)),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _summaries.length,
                              itemBuilder: (context, index) {
                                final summary = _summaries[index];
                                final cardBg = index.isEven ? cardA : cardB;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 0,
                                  color: cardBg,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: Colors.teal[200]!, width: 1),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => SalesmanDetailScreen(
                                            salesmanName: summary.salesman,
                                          ),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: const Color(0xFFB2DFDB),
                                            child: const Icon(
                                              Icons.person,
                                              color: Color(0xFF004D40),
                                            ),
                                          ),
                                          const SizedBox(width: 16),

                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  summary.salesman,
                                                  style: theme.textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(0xFF004D40),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${summary.pharmacyCount} ${summary.pharmacyCount == 1 ? "Pharmacy" : "Pharmacies"}',
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    color: const Color(0xFF00695C),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                formatIndianCurrency(summary.totalDue),
                                                style: theme.textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFF004D40),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Outstanding',
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: const Color(0xFF00695C),
                                                  fontSize: 10,
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
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
