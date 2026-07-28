// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pharmacy.dart';
import '../models/reminder.dart';
import '../data/pharmacy_repository.dart';
import '../data/reminder_repository.dart';
import '../providers/app_state.dart';
import '../services/notification_service.dart';

class LogRescheduleCallDialog extends StatefulWidget {
  final Pharmacy? pharmacy;
  final String? salesmanName;
  final Reminder? reminder; // Optional existing pending reminder

  const LogRescheduleCallDialog({
    super.key,
    this.pharmacy,
    this.salesmanName,
    this.reminder,
  });

  @override
  State<LogRescheduleCallDialog> createState() => _LogRescheduleCallDialogState();
}

class _LogRescheduleCallDialogState extends State<LogRescheduleCallDialog> {
  final PharmacyRepository _pharmacyRepo = PharmacyRepository();
  final ReminderRepository _reminderRepo = ReminderRepository();

  String _targetType = 'pharmacy'; // 'pharmacy' or 'salesman'
  Pharmacy? _selectedPharmacy;
  String? _selectedSalesmanName;

  String _searchQuery = '';
  List<Pharmacy> _searchResults = [];

  String _salesmanSearchQuery = '';
  List<String> _salesmanSearchResults = [];

  bool _isSearching = false;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedPharmacy = widget.pharmacy;
    _selectedSalesmanName = widget.salesmanName;

    if (widget.reminder != null) {
      _targetType = widget.reminder!.reminderType;
      if (_targetType == 'pharmacy') {
        _selectedSalesmanName = null;
        if (_selectedPharmacy == null) {
          _loadPharmacyForReminder();
        }
      } else {
        _selectedPharmacy = null;
        _selectedSalesmanName = widget.reminder!.salesmanName;
      }
      _isSearching = false;
    } else if (widget.pharmacy != null) {
      _targetType = 'pharmacy';
      _selectedPharmacy = widget.pharmacy;
      _selectedSalesmanName = null;
      _isSearching = false;
    } else if (widget.salesmanName != null) {
      _targetType = 'salesman';
      _selectedPharmacy = null;
      _selectedSalesmanName = widget.salesmanName;
      _isSearching = false;
    } else {
      _targetType = 'pharmacy';
      _selectedPharmacy = null;
      _selectedSalesmanName = null;
      _isSearching = true;
      _performSearch('');
    }
  }

  Future<void> _loadPharmacyForReminder() async {
    if (widget.reminder?.pharmacyId != null) {
      final ph = await _pharmacyRepo.getById(widget.reminder!.pharmacyId!);
      if (mounted && ph != null) {
        setState(() {
          _selectedPharmacy = ph;
        });
      }
    }
  }

  Future<void> _performSearch(String query) async {
    final results = await _pharmacyRepo.searchPharmacies(query);
    setState(() {
      _searchResults = results;
      _searchQuery = query;
    });
  }

  Future<void> _performSalesmanSearch(String query) async {
    final summary = await _pharmacyRepo.getSalesmenSummary();
    final names = summary.map((s) => s.salesman).where((name) {
      return name.toLowerCase().contains(query.toLowerCase());
    }).toList();
    setState(() {
      _salesmanSearchResults = names;
      _salesmanSearchQuery = query;
    });
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    print('--- _submit() START --- targetType: $_targetType, date: $_selectedDate, time: $_selectedTime');
    if (_targetType == 'pharmacy') {
      if (_selectedPharmacy == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a pharmacy first')),
        );
        return;
      }
    } else {
      if (_selectedSalesmanName == null || _selectedSalesmanName!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a salesman first')),
        );
        return;
      }
    }

    final appState = Provider.of<AppState>(context, listen: false);
    final notes = _notesController.text.trim();
    final nowStr = DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19);

    Reminder? pendingReminder = widget.reminder;
    if (_targetType == 'pharmacy') {
      pendingReminder ??= await _reminderRepo.getNextPendingReminder(_selectedPharmacy!.id!);
    } else {
      pendingReminder ??= await _reminderRepo.getNextPendingReminderForSalesman(_selectedSalesmanName!);
    }

    if (_selectedDate != null) {
      if (pendingReminder != null) {
        if (pendingReminder.notificationId != null) {
          await NotificationService().cancelNotification(pendingReminder.notificationId!);
        }
        await _reminderRepo.markRescheduled(
          pendingReminder.id!,
          notes: notes.isNotEmpty ? notes : null,
        );
      }

      final newReminder = Reminder(
        reminderType: _targetType,
        pharmacyId: _targetType == 'pharmacy' ? _selectedPharmacy!.id! : null,
        salesmanName: _targetType == 'salesman' ? _selectedSalesmanName : null,
        scheduledDate: _formatDate(_selectedDate!),
        scheduledTime: _selectedTime != null ? _formatTime(_selectedTime!) : null,
        status: 'pending',
        notes: null,
        createdAt: nowStr,
      );
      final newId = await _reminderRepo.create(newReminder);
      if (_selectedTime != null) {
        await NotificationService().scheduleReminderNotification(newId);
      }
    } else {
      if (pendingReminder != null) {
        if (pendingReminder.notificationId != null) {
          await NotificationService().cancelNotification(pendingReminder.notificationId!);
        }
        await _reminderRepo.markDone(
          pendingReminder.id!,
          notes: notes.isNotEmpty ? notes : null,
        );
      } else {
        final completedCall = Reminder(
          reminderType: _targetType,
          pharmacyId: _targetType == 'pharmacy' ? _selectedPharmacy!.id! : null,
          salesmanName: _targetType == 'salesman' ? _selectedSalesmanName : null,
          scheduledDate: _formatDate(DateTime.now()),
          scheduledTime: _formatTime(TimeOfDay.fromDateTime(DateTime.now())),
          status: 'done',
          notes: notes.isNotEmpty ? notes : null,
          createdAt: nowStr,
        );
        await _reminderRepo.create(completedCall);
      }
    }

    print('--- _submit() END ---');
    appState.refresh();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[350],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  _isSearching
                      ? (_targetType == 'pharmacy' ? 'Select Pharmacy' : 'Select Salesman')
                      : 'Log / Reschedule Call',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                if (_isSearching) ...[
                  if (widget.pharmacy == null && widget.salesmanName == null && widget.reminder == null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Pharmacy')),
                            selected: _targetType == 'pharmacy',
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _targetType = 'pharmacy';
                                  _performSearch('');
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Salesman')),
                            selected: _targetType == 'salesman',
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _targetType = 'salesman';
                                  _performSalesmanSearch('');
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_targetType == 'pharmacy') ...[
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search Pharmacy by Name',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: _performSearch,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 250,
                      child: _searchResults.isEmpty
                          ? Center(
                              child: Text(
                                _searchQuery.isEmpty ? 'Type to search pharmacies' : 'No pharmacies found',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final ph = _searchResults[index];
                                return ListTile(
                                  title: Text(ph.name),
                                  subtitle: Text('Code: ${ph.partyCode}'),
                                  onTap: () {
                                    setState(() {
                                      _selectedPharmacy = ph;
                                      _isSearching = false;
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ] else ...[
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search Salesman by Name',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: _performSalesmanSearch,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 250,
                      child: _salesmanSearchResults.isEmpty
                          ? Center(
                              child: Text(
                                _salesmanSearchQuery.isEmpty ? 'Type to search salesmen' : 'No salesmen found',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _salesmanSearchResults.length,
                              itemBuilder: (context, index) {
                                final name = _salesmanSearchResults[index];
                                return ListTile(
                                  leading: const Icon(Icons.person),
                                  title: Text(name),
                                  onTap: () {
                                    setState(() {
                                      _selectedSalesmanName = name;
                                      _isSearching = false;
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: _targetType == 'pharmacy' && _selectedPharmacy == null
                          ? const Center(child: CircularProgressIndicator())
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _targetType == 'pharmacy'
                                            ? _selectedPharmacy!.name
                                            : _selectedSalesmanName!,
                                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _targetType == 'pharmacy'
                                            ? 'Pharmacy (Code: ${_selectedPharmacy!.partyCode})'
                                            : 'Sales Representative',
                                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.pharmacy == null && widget.salesmanName == null && widget.reminder == null)
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isSearching = true;
                                        _searchResults = [];
                                        _searchQuery = '';
                                        _salesmanSearchResults = [];
                                        _salesmanSearchQuery = '';
                                      });
                                    },
                                    child: const Text('Change'),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Next Call Date (Optional)'),
                    subtitle: Text(
                      _selectedDate == null ? 'Not scheduled (Log call as completed)' : _formatDate(_selectedDate!),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selectedDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _selectedDate = null;
                                _selectedTime = null;
                              });
                            },
                          ),
                        const Icon(Icons.calendar_today),
                      ],
                    ),
                    onTap: _selectDate,
                  ),
                  const Divider(),

                  if (_selectedDate != null) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Next Call Time (Optional)'),
                      subtitle: Text(
                        _selectedTime == null ? 'Not set' : _selectedTime!.format(context),
                      ),
                      trailing: const Icon(Icons.access_time),
                      onTap: _selectTime,
                    ),
                    const Divider(),
                  ],

                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Call Outcome Notes',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                      hintText: 'Enter notes describing the call...',
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                          ),
                          child: Text(_selectedDate == null ? 'Log Call as Done' : 'Reschedule & Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
