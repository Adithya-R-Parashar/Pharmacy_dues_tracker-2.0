// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pharmacy.dart';
import '../models/reminder.dart';
import '../data/pharmacy_repository.dart';
import '../data/reminder_repository.dart';
import '../providers/app_state.dart';
import '../services/notification_service.dart';
import '../services/phone_call_service.dart';

class LogRescheduleCallDialog extends StatefulWidget {
  final Pharmacy? pharmacy;
  final String? salesmanName;
  final Reminder? reminder;

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

  String _targetType = 'pharmacy';
  Pharmacy? _selectedPharmacy;
  String? _selectedSalesmanName;
  String? _selectedSalesmanPhone;

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
      _notesController.text = widget.reminder!.notes ?? '';
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

    if (_selectedSalesmanName != null) {
      _fetchSalesmanPhone(_selectedSalesmanName!);
    }
  }

  Future<void> _fetchSalesmanPhone(String name) async {
    final phone = await _pharmacyRepo.getSalesmanPhone(name);
    if (mounted) {
      setState(() {
        _selectedSalesmanPhone = phone;
      });
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
        notes: notes.isNotEmpty ? notes : null,
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

    return Container(
      color: Colors.white,
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
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF004D40),
                  ),
                ),
                const SizedBox(height: 16),

                if (_isSearching) ...[
                  if (widget.pharmacy == null && widget.salesmanName == null && widget.reminder == null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Pharmacy', maxLines: 1, overflow: TextOverflow.ellipsis)),
                            selected: _targetType == 'pharmacy',
                            selectedColor: const Color(0xFFB2DFDB),
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
                            label: const Center(child: Text('Salesman', maxLines: 1, overflow: TextOverflow.ellipsis)),
                            selected: _targetType == 'salesman',
                            selectedColor: const Color(0xFFB2DFDB),
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
                        prefixIcon: Icon(Icons.search, color: Color(0xFF00695C)),
                        border: OutlineInputBorder(),
                        fillColor: Color(0xFFF5F5F5),
                        filled: true,
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
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final ph = _searchResults[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      ph.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                                    ),
                                    subtitle: Text(
                                      'Code: ${ph.partyCode}',
                                      style: const TextStyle(color: Color(0xFF00695C)),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedPharmacy = ph;
                                        _isSearching = false;
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ] else ...[
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search Salesman by Name',
                        prefixIcon: Icon(Icons.search, color: Color(0xFF00695C)),
                        border: OutlineInputBorder(),
                        fillColor: Color(0xFFF5F5F5),
                        filled: true,
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
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _salesmanSearchResults.length,
                              itemBuilder: (context, index) {
                                final name = _salesmanSearchResults[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListTile(
                                    leading: const Icon(Icons.person, color: Color(0xFF00695C)),
                                    title: Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                                    ),
                                    onTap: () {
                                       setState(() {
                                         _selectedSalesmanName = name;
                                         _isSearching = false;
                                       });
                                       _fetchSalesmanPhone(name);
                                     },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00695C),
                          side: const BorderSide(color: Color(0xFF00695C)),
                        ),
                        child: const Text('Cancel', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: _targetType == 'pharmacy' && _selectedPharmacy == null
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00695C)))
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
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF004D40),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _targetType == 'pharmacy'
                                          ? 'Pharmacy (Code: ${_selectedPharmacy!.partyCode})'
                                          : 'Sales Representative',
                                      style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF00695C)),
                                    ),
                                  ],
                                ),
                              ),
                               if (_targetType == 'salesman')
                                 IconButton(
                                   icon: const Icon(Icons.call, color: Color(0xFF00695C)),
                                   tooltip: 'Call Salesman',
                                   onPressed: () => PhoneCallService.call(context, _selectedSalesmanPhone),
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
                                   child: const Text('Change', style: TextStyle(color: Color(0xFF00695C))),
                                 ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: const Text('Next Call Date (Optional)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                      subtitle: Text(
                        _selectedDate == null ? 'Not scheduled (Log call as completed)' : _formatDate(_selectedDate!),
                        style: const TextStyle(color: Color(0xFF00695C)),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectedDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Color(0xFF00695C)),
                              onPressed: () {
                                setState(() {
                                  _selectedDate = null;
                                  _selectedTime = null;
                                });
                              },
                            ),
                          const Icon(Icons.calendar_today, color: Color(0xFF00695C)),
                        ],
                      ),
                      onTap: _selectDate,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_selectedDate != null) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: const Text('Next Call Time (Optional)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                        subtitle: Text(
                          _selectedTime == null ? 'Not set' : _selectedTime!.format(context),
                          style: const TextStyle(color: Color(0xFF00695C)),
                        ),
                        trailing: const Icon(Icons.access_time, color: Color(0xFF00695C)),
                        onTap: _selectTime,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    style: const TextStyle(color: Color(0xFF004D40)),
                    decoration: const InputDecoration(
                      labelText: 'Call Outcome Notes',
                      labelStyle: TextStyle(color: Color(0xFF00695C)),
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                      fillColor: Color(0xFFF5F5F5),
                      filled: true,
                      hintText: 'Enter notes describing the call...',
                    ),
                  ),
                  const SizedBox(height: 24),

                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00695C),
                          side: const BorderSide(color: Color(0xFF00695C)),
                        ),
                        child: const Text('Cancel', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00695C),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          _selectedDate == null ? 'Log Call as Done' : 'Reschedule & Save',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
