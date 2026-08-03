// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/database_helper.dart';
import '../services/excel_import_service.dart';
import '../services/excel_test_generator.dart';
import '../providers/app_state.dart';
import '../theme.dart';

class ImportView extends StatefulWidget {
  const ImportView({super.key});

  @override
  State<ImportView> createState() => _ImportViewState();
}

class _ImportViewState extends State<ImportView> {
  bool _isProcessing = false;
  String _progressMessage = '';

  void _showResultDialog(ImportResult result) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Import Results'),
          contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatRow('New Pharmacies Created', result.newPharmacies),
                  _buildStatRow('Existing Pharmacies Matched', result.matchedPharmacies),
                  _buildStatRow('Snapshots Updated', result.snapshotsUpdated),
                  const Divider(),
                  _buildStatRow('Invalid/Skipped Rows', result.skippedInvalidRows),

                  if (result.skippedReasons.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Skipped Row Details:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: result.skippedReasons.map((reason) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(
                              reason,
                              style: TextStyle(color: Colors.red[800], fontSize: 13),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndImport() async {
    setState(() {
      _isProcessing = true;
      _progressMessage = 'Decoding Excel file...';
    });

    try {
      final result = await ExcelImportService().pickAndImportExcel(
        onProgress: (processed, total) {
          setState(() {
            _progressMessage = 'Processing $processed of $total rows...';
          });
        },
      );
      if (result != null) {
        if (mounted) {
          Provider.of<AppState>(context, listen: false).refresh();
          _showResultDialog(result);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No file selected or import cancelled')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import Error'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _runProgrammaticTestImport() async {
    setState(() {
      _isProcessing = true;
      _progressMessage = 'Running Programmatic Verification Tests...';
    });

    try {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;

      await db.delete('reminders');
      await db.delete('pharmacies');

      final groupedBytes = ExcelTestGenerator.generateGroupedExcelBytes();
      final groupedResult = await ExcelImportService().importExcelFromBytes(
        groupedBytes,
        onProgress: (processed, total) {
          setState(() {
            _progressMessage = 'Processing grouped rows ($processed/$total)...';
          });
        },
      );

      final pharmacies = await db.query('pharmacies');

      double sunshineDues = 0.0;
      double greenLeafDues = 0.0;

      for (final ph in pharmacies) {
        final code = ph['party_code'];
        final total = (ph['total_amount'] as num?)?.toDouble() ?? 0.0;
        if (code == 'SUN-101') sunshineDues = total;
        if (code == 'GRN-202') greenLeafDues = total;
      }

      final groupedPass = pharmacies.length == 2 &&
          groupedResult.skippedInvalidRows == 0 &&
          sunshineDues == 9200.0 &&
          greenLeafDues == 3500.0;

      print('==================================================');
      print('TEST 1: Grouped/Aging-Format Excel Import');
      print('  Pharmacies Imported: ${pharmacies.length} (Expected: 2)');
      print('  Skipped Invalid Rows: ${groupedResult.skippedInvalidRows} (Expected: 0)');
      print('  Sunshine Pharmacy Dues: ₹$sunshineDues (Expected: 9200.0)');
      print('  Green Leaf Dues: ₹$greenLeafDues (Expected: 3500.0)');
      print('  STATUS: ${groupedPass ? "PASS" : "FAIL"}');
      print('==================================================');

      await db.delete('reminders');
      await db.delete('pharmacies');

      final flatBytes = ExcelTestGenerator.generateTestExcelBytes();
      final flatResult = await ExcelImportService().importExcelFromBytes(
        flatBytes,
        onProgress: (processed, total) {
          setState(() {
            _progressMessage = 'Processing flat rows ($processed/$total)...';
          });
        },
      );

      final pharmaciesFlat = await db.query('pharmacies');

      final flatPass = pharmaciesFlat.length == 2 &&
          flatResult.skippedInvalidRows == 2;

      print('==================================================');
      print('TEST 2: Regression Flat-Format Excel Import');
      print('  Pharmacies Imported: ${pharmaciesFlat.length} (Expected: 2)');
      print('  Skipped Invalid Rows: ${flatResult.skippedInvalidRows} (Expected: 2)');
      print('  STATUS: ${flatPass ? "PASS" : "FAIL"}');
      print('==================================================');

      await db.delete('reminders');
      await db.delete('pharmacies');
      final finalResult = await ExcelImportService().importExcelFromBytes(groupedBytes);

      if (mounted) {
        Provider.of<AppState>(context, listen: false).refresh();
        _showResultDialog(finalResult);

        final allPass = groupedPass && flatPass;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(allPass
                ? 'All Programmatic Tests Passed Successfully!'
                : 'Some Tests Failed! Check console log.'),
            backgroundColor: allPass ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test import failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF00695C),
          elevation: 1,
          shadowColor: Colors.black12,
          title: const Text('Import Data'),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: AppTheme.appBackground,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 4,
                    color: Colors.white.withValues(alpha: 0.95),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.upload_file_rounded,
                            size: 64,
                            color: Color(0xFF00695C),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Excel Import',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF004D40),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Upload your pharmacy dues Excel sheet (.xlsx) to update local pharmacy and aging bucket balances.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF00695C)),
                          ),
                          const SizedBox(height: 24),

                          if (_isProcessing) ...[
                            const CircularProgressIndicator(color: Color(0xFF00695C)),
                            const SizedBox(height: 16),
                            Text(
                              _progressMessage,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF004D40),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ] else ...[
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _pickAndImport,
                                  icon: const Icon(Icons.file_open),
                                  label: const Text(
                                    'Import Excel from Device',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00695C),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _runProgrammaticTestImport,
                                  icon: const Icon(Icons.bug_report),
                                  label: const Text(
                                    'Run In-Memory Test Import',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF00695C),
                                    side: const BorderSide(color: Color(0xFF00695C)),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
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
                ],
              ),
            ),
        ),
      ),
    ),
  );
}
}
