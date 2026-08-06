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

class PharmacyDetailScreen extends StatefulWidget {
  final Pharmacy pharmacy;

  const PharmacyDetailScreen({
    super.key,
    required this.pharmacy,
  });

  @override
  State<PharmacyDetailScreen> createState() => _PharmacyDetailScreenState();
}

class _PharmacyDetailScreenState extends State<PharmacyDetailScreen> {
  final PharmacyRepository _pharmacyRepo = PharmacyRepository();
  final ReminderRepository _reminderRepo = ReminderRepository();

  bool _isLoading = true;
  late Pharmacy _pharmacy;
  List<Reminder> _callHistory = [];

  late TextEditingController _notesController;
  late FocusNode _notesFocusNode;

  @override
  void initState() {
    super.initState();
    _pharmacy = widget.pharmacy;
    _notesController = TextEditingController(text: _pharmacy.notes ?? '');
    _notesFocusNode = FocusNode();
    _notesFocusNode.addListener(_onNotesFocusChange);
    _loadData();
  }

  @override
  void dispose() {
    _notesFocusNode.removeListener(_onNotesFocusChange);
    _notesFocusNode.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Provider.of<AppState>(context);
    _loadData();
  }

  void _onNotesFocusChange() {
    if (!_notesFocusNode.hasFocus) {
      _saveNotes();
    }
  }

  Future<void> _saveNotes() async {
    if (_pharmacy.id == null) return;
    final newNotes = _notesController.text.trim();
    await _pharmacyRepo.updateNotes(_pharmacy.id!, newNotes);
    if (mounted) {
      Provider.of<AppState>(context, listen: false).refresh();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final pharmacyId = widget.pharmacy.id!;
    final updatedPharmacy = await _pharmacyRepo.getById(pharmacyId);
    final history = await _reminderRepo.getByPharmacy(pharmacyId);

    if (mounted) {
      setState(() {
        if (updatedPharmacy != null) {
          _pharmacy = updatedPharmacy;
          if (!_notesFocusNode.hasFocus) {
            _notesController.text = _pharmacy.notes ?? '';
          }
        }
        _callHistory = history;
        _isLoading = false;
      });
    }
  }

  void _openLogCallDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => LogRescheduleCallDialog(
        pharmacy: _pharmacy,
      ),
    ).then((_) => _loadData());
  }

  Future<void> _confirmDeletePharmacy() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Pharmacy'),
          content: Text(
            'Delete ${_pharmacy.name}? This will also delete all call reminders for this pharmacy. This cannot be undone.',
          ),
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
      await _pharmacyRepo.deletePharmacy(_pharmacy.id!);
      if (mounted) {
        Provider.of<AppState>(context, listen: false).refresh();
        Navigator.of(context).pop();
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.blue[800]!;
      case 'done':
        return Colors.green[800]!;
      case 'rescheduled':
        return Colors.orange[800]!;
      default:
        return Colors.grey[800]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final double totalAmount = _pharmacy.totalAmount ?? 0.0;
    final double? b121 = _pharmacy.bucket121180;
    final double? b181 = _pharmacy.bucket181270;
    final double? b271 = _pharmacy.bucket271360;

    final has121 = b121 != null && b121 > 0;
    final has181 = b181 != null && b181 > 0;
    final has271 = b271 != null && b271 > 0;

    final cardA = Colors.white.withValues(alpha: 0.95);
    const cardB = Color(0xFFE0F2F1);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
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
          _pharmacy.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete Pharmacy',
            onPressed: _confirmDeletePharmacy,
          ),
          IconButton(
            icon: const Icon(Icons.phone_in_talk, color: Color(0xFF00695C)),
            tooltip: 'Log Call',
            onPressed: _openLogCallDialog,
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
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Summary Card: Pharmacy Info
                      Card(
                        margin: EdgeInsets.zero,
                        color: cardA,
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
                                children: [
                                  Expanded(
                                    child: Text(
                                      _pharmacy.name,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF004D40),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    'Party Code: ',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF00695C)),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _pharmacy.partyCode,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF004D40),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_pharmacy.salesman != null && _pharmacy.salesman!.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      'Salesman: ',
                                      style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF00695C)),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _pharmacy.salesman!,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF004D40),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (_pharmacy.city != null && _pharmacy.city!.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      'City: ',
                                      style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF00695C)),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _pharmacy.city!,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF004D40),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (_pharmacy.category != null && _pharmacy.category!.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      'Category: ',
                                      style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF00695C)),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _pharmacy.category!,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF004D40),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // "Current Outstanding" section
                      Card(
                        margin: EdgeInsets.zero,
                        color: cardB,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.teal[200]!, width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Outstanding',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF004D40),
                                ),
                              ),
                              if (_pharmacy.lastImportDate != null && _pharmacy.lastImportDate!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'As of ${_pharmacy.lastImportDate}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF00695C),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Total Outstanding:',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF004D40),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    formatIndianCurrency(totalAmount),
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF004D40),
                                    ),
                                  ),
                                ],
                              ),

                              if (has121 || has181 || has271) ...[
                                const Divider(height: 20, color: Color(0xFFB2DFDB)),
                                if (has121)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '121 - 150 Days:',
                                            style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF00695C)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          formatIndianCurrency(b121),
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF004D40),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (has181)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '151 - 270 Days:',
                                            style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF00695C)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          formatIndianCurrency(b181),
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF004D40),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (has271)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '271 - 360 Days:',
                                            style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF00695C)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          formatIndianCurrency(b271),
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF004D40),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Pharmacy Notes section
                      Text(
                        'Notes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF004D40),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        focusNode: _notesFocusNode,
                        minLines: 2,
                        maxLines: 4,
                        onEditingComplete: _saveNotes,
                        style: const TextStyle(color: Color(0xFF004D40)),
                        decoration: InputDecoration(
                          hintText: 'Tap to add a note about this pharmacy...',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          fillColor: Colors.white.withValues(alpha: 0.95),
                          filled: true,
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.teal[200]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.teal[200]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF00695C), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Call Log History Section
                      Text(
                        'Call Log History',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF004D40),
                        ),
                      ),
                      const SizedBox(height: 8),

                      _callHistory.isEmpty
                          ? Card(
                              margin: EdgeInsets.zero,
                              color: cardA,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.teal[200]!, width: 1),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Center(
                                  child: Text(
                                    'No call history recorded.',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF00695C)),
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _callHistory.length,
                              itemBuilder: (context, index) {
                                final rem = _callHistory[index];
                                final statusColor = _getStatusColor(rem.status);
                                final timeStr = rem.scheduledTime != null ? ' at ${rem.scheduledTime}' : '';
                                final cardBg = index.isEven ? cardA : cardB;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
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
                                            Text(
                                              '${rem.scheduledDate}$timeStr',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF004D40),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                rem.status.toUpperCase(),
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (rem.notes != null && rem.notes!.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            rem.notes!,
                                            style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF00695C)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ElevatedButton.icon(
              onPressed: _openLogCallDialog,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: const Color(0xFF00695C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_call),
              label: const Text(
                'Log a Call',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
