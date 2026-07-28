import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/database_helper.dart';
import '../providers/app_state.dart';
import 'manage_cities_screen.dart';
import '../services/notification_service.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final TextEditingController _confirmController = TextEditingController();
  bool _canWipe = false;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _clearAllData() async {
    _confirmController.clear();
    setState(() {
      _canWipe = false;
    });

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Clear All Data?', style: TextStyle(color: Colors.red)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This action is highly destructive and will permanently delete all pharmacies, invoices, and call logs from this device.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('Please type "DELETE" to confirm:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'DELETE',
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        _canWipe = val.trim() == 'DELETE';
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _canWipe ? () => Navigator.of(context).pop(true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm Wipe'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      await NotificationService().cancelAllNotifications();
      final db = await DatabaseHelper.instance.database;
      
      // Perform database wipe
      await db.transaction((txn) async {
        await txn.delete('reminders');
        await txn.delete('invoices');
        await txn.delete('pharmacies');
      });

      if (mounted) {
        Provider.of<AppState>(context, listen: false).refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All local tables have been cleared successfully.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
        children: [
          // App Info Header Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Icon(
                    Icons.settings_applications,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pharmacy Dues Tracker',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version 1.0.0',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[650]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'General Settings',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Card(
            child: ListTile(
              leading: const Icon(Icons.location_city, color: Colors.blue),
              title: const Text(
                'Manage Cities',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Merge spelling variants and manage city aliases'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ManageCitiesScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Actions List
          Text(
            'Maintenance Actions',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Card(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Clear All Local Data',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Delete all local pharmacies, invoices, and call records'),
              trailing: const Icon(Icons.chevron_right, color: Colors.red),
              onTap: _clearAllData,
            ),
          ),
        ],
      ),
    ),
  );
  }
}
