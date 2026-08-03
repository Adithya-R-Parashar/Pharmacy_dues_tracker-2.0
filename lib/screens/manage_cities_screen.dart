import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/pharmacy_repository.dart';
import '../data/city_alias_repository.dart';
import '../providers/app_state.dart';
import '../theme.dart';

class ManageCitiesScreen extends StatefulWidget {
  const ManageCitiesScreen({super.key});

  @override
  State<ManageCitiesScreen> createState() => _ManageCitiesScreenState();
}

class _ManageCitiesScreenState extends State<ManageCitiesScreen> {
  final PharmacyRepository _pharmacyRepo = PharmacyRepository();
  final CityAliasRepository _aliasRepo = CityAliasRepository();

  bool _isLoading = true;
  List<String> _distinctCities = [];
  List<CityAlias> _aliases = [];
  final Set<String> _selectedCities = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final cities = await _pharmacyRepo.getDistinctCities();
      final aliases = await _aliasRepo.getAllAliases();
      if (!mounted) return;
      setState(() {
        _distinctCities = cities;
        _aliases = aliases;
        _selectedCities.clear();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load cities: $e')),
      );
    }
  }

  Future<void> _mergeSelected() async {
    final list = _selectedCities.toList();
    if (list.length < 2) return;

    final canonical = await showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        String selected = list.first;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Canonical Name'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose the correct spelling that all selected names will merge into:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ...list.map((city) {
                    final isSelected = selected == city;
                    return ListTile(
                      title: Text(city),
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: isSelected ? theme.colorScheme.primary : null,
                      ),
                      onTap: () {
                        setDialogState(() {
                          selected = city;
                        });
                      },
                    );
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(selected),
                  child: const Text('Merge & Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (canonical != null && canonical.isNotEmpty && mounted) {
      await _aliasRepo.mergeCities(list, canonical);

      if (mounted) {
        Provider.of<AppState>(context, listen: false).refresh();
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Merged ${list.length} cities into "$canonical"'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<void> _undoAlias(CityAlias alias) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Alias Rule'),
          content: Text('Remove alias "${alias.rawValue} → ${alias.canonicalCity}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      await _aliasRepo.removeAlias(alias.rawValue);
      if (mounted) {
        Provider.of<AppState>(context, listen: false).refresh();
        await _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canMerge = _selectedCities.length >= 2;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF00695C),
        elevation: 1,
        shadowColor: Colors.black12,
        title: const Text('Manage Cities'),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Select Cities to Merge',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF004D40),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: canMerge ? _mergeSelected : null,
                            icon: const Icon(Icons.call_merge, size: 18),
                            label: Text('Merge (${_selectedCities.length})'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00695C),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select two or more city spelling variations to merge into a single canonical city name.',
                        style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF00695C)),
                      ),
                      const SizedBox(height: 16),

                      _distinctCities.isEmpty
                          ? Card(
                              color: Colors.white.withValues(alpha: 0.95),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Center(
                                  child: Text(
                                    'No cities found in local database.',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF00695C)),
                                  ),
                                ),
                              ),
                            )
                          : Card(
                              margin: EdgeInsets.zero,
                              color: Colors.white.withValues(alpha: 0.95),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.teal[200]!, width: 1),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _distinctCities.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final city = _distinctCities[index];
                                  final isChecked = _selectedCities.contains(city);

                                  return CheckboxListTile(
                                    title: Text(city, style: const TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
                                    value: isChecked,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedCities.add(city);
                                        } else {
                                          _selectedCities.remove(city);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                            ),

                      const SizedBox(height: 32),

                      Text(
                        'Active Normalization Rules',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF004D40),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Spelling variations automatically resolved and standardized on future imports.',
                        style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF00695C)),
                      ),
                      const SizedBox(height: 12),

                      _aliases.isEmpty
                          ? Card(
                              color: Colors.white.withValues(alpha: 0.95),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Center(
                                  child: Text(
                                    'No alias rules configured yet.',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF00695C)),
                                  ),
                                ),
                              ),
                            )
                          : Card(
                              margin: EdgeInsets.zero,
                              color: Colors.white.withValues(alpha: 0.95),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.teal[200]!, width: 1),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _aliases.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final alias = _aliases[index];
                                  return ListTile(
                                    leading: const Icon(Icons.compare_arrows, color: Color(0xFF00695C)),
                                    title: Text(
                                      '${alias.rawValue} → ${alias.canonicalCity}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                                    ),
                                    subtitle: Text('Created: ${alias.createdAt.split("T").first}', style: const TextStyle(color: Color(0xFF00695C))),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => _undoAlias(alias),
                                    ),
                                  );
                                },
                              ),
                            ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
