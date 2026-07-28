import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/pharmacy_repository.dart';
import '../data/city_alias_repository.dart';
import '../providers/app_state.dart';

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
                  child: const Text('Merge'),
                ),
              ],
            );
          },
        );
      },
    );

    if (canonical != null) {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });
      try {
        await _aliasRepo.mergeCities(list, canonical);
        if (!mounted) return;
        Provider.of<AppState>(context, listen: false).refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Merged city names into "$canonical".')),
        );
        await _loadData();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Merge failed: $e')),
        );
      }
    }
  }

  Future<void> _undoAlias(CityAlias alias) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _aliasRepo.removeAlias(alias.rawValue);
      if (!mounted) return;
      Provider.of<AppState>(context, listen: false).refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted alias rule for "${alias.rawValue}".')),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Undo failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canMerge = _selectedCities.length >= 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Cities'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checklist section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active City Spellings',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: canMerge ? _mergeSelected : null,
                        icon: const Icon(Icons.merge_type, size: 16),
                        label: const Text('Merge Selected'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select 2 or more cities to merge spelling variations and map them to a canonical name.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[650]),
                  ),
                  const SizedBox(height: 12),

                  _distinctCities.isEmpty
                      ? Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(
                              child: Text(
                                'No cities found in local database.',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                              ),
                            ),
                          ),
                        )
                      : Card(
                          margin: EdgeInsets.zero,
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _distinctCities.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final city = _distinctCities[index];
                              final isChecked = _selectedCities.contains(city);

                              return CheckboxListTile(
                                title: Text(city),
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

                  // Aliases section
                  Text(
                    'Active Normalization Rules',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Spelling variations automatically resolved and standardized on future imports.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[650]),
                  ),
                  const SizedBox(height: 12),

                  _aliases.isEmpty
                      ? Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(
                              child: Text(
                                'No alias rules configured yet.',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                              ),
                            ),
                          ),
                        )
                      : Card(
                          margin: EdgeInsets.zero,
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _aliases.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final alias = _aliases[index];
                              return ListTile(
                                leading: const Icon(Icons.compare_arrows, color: Colors.blue),
                                title: Text('${alias.rawValue} → ${alias.canonicalCity}'),
                                subtitle: Text('Created: ${alias.createdAt.split("T").first}'),
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
    );
  }
}
