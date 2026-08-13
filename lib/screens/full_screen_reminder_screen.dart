import 'package:flutter/material.dart';
import '../services/phone_call_service.dart';
import '../services/formatters.dart';
import '../data/pharmacy_repository.dart';
import '../models/pharmacy.dart';
import 'pharmacy_detail_screen.dart';
import 'salesman_detail_screen.dart';

class FullScreenReminderScreen extends StatefulWidget {
  final String reminderType; // 'pharmacy' or 'salesman'
  final int? pharmacyId;
  final String? salesmanName;

  const FullScreenReminderScreen({
    super.key,
    required this.reminderType,
    this.pharmacyId,
    this.salesmanName,
  });

  @override
  State<FullScreenReminderScreen> createState() => _FullScreenReminderScreenState();
}

class _FullScreenReminderScreenState extends State<FullScreenReminderScreen> {
  Pharmacy? _pharmacy;
  String? _phoneNumber;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = PharmacyRepository();
    if (widget.reminderType == 'pharmacy' && widget.pharmacyId != null) {
      final ph = await repo.getById(widget.pharmacyId!);
      final phone = ph?.salesman != null ? await repo.getSalesmanPhone(ph!.salesman!) : null;
      if (mounted) {
        setState(() {
          _pharmacy = ph;
          _phoneNumber = phone;
          _isLoading = false;
        });
      }
    } else if (widget.reminderType == 'salesman' && widget.salesmanName != null) {
      final phone = await repo.getSalesmanPhone(widget.salesmanName!);
      if (mounted) {
        setState(() {
          _phoneNumber = phone;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _dismiss() {
    Navigator.of(context).pop();
  }

  void _viewDetails() {
    if (widget.reminderType == 'pharmacy' && _pharmacy != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PharmacyDetailScreen(pharmacy: _pharmacy!)),
      );
    } else if (widget.reminderType == 'salesman' && widget.salesmanName != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SalesmanDetailScreen(salesmanName: widget.salesmanName!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.reminderType == 'pharmacy'
        ? (_pharmacy?.name ?? 'Pharmacy Call Reminder')
        : 'Call Salesman ${widget.salesmanName ?? ''}';
    final amount = widget.reminderType == 'pharmacy' ? _pharmacy?.totalAmount : null;

    return PopScope(
      canPop: false, // require an explicit action, not a back-swipe
      child: Scaffold(
        backgroundColor: const Color(0xFF00695C),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.phone_in_talk, color: Colors.white, size: 72),
                      const SizedBox(height: 24),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      if (amount != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          '${formatIndianCurrency(amount)} outstanding',
                          style: const TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                      ],
                      const Spacer(),
                      if (_phoneNumber != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => PhoneCallService.call(context, _phoneNumber),
                            icon: const Icon(Icons.call),
                            label: const Text('Call Now', style: TextStyle(fontSize: 18)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF00695C),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _viewDetails,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('View Details', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _dismiss,
                        child: const Text('Dismiss', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
