import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/user_service.dart';
import '../models/case_time_entry.dart';
import '../services/case_management_service.dart';

class CaseTimeEntriesTab extends StatefulWidget {
  final String caseId;
  final int defaultHourlyRate;
  const CaseTimeEntriesTab({super.key, required this.caseId, required this.defaultHourlyRate});

  @override
  State<CaseTimeEntriesTab> createState() => _CaseTimeEntriesTabState();
}

class _CaseTimeEntriesTabState extends State<CaseTimeEntriesTab> {
  final CaseManagementService _caseService = CaseManagementService();
  List<CaseTimeEntry> _entries = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchEntries();
  }

  Future<void> _fetchEntries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final entries = await _caseService.getTimeEntries(widget.caseId);
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showAddTimeDialog() {
    final descController = TextEditingController();
    final minutesController = TextEditingController();
    final hourlyRateController = TextEditingController(text: (widget.defaultHourlyRate / 100).toString());
    DateTime entryDate = DateTime.now();
    bool billable = true;
    String? selectedTaskId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Capture Time'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                TextField(
                  controller: minutesController,
                  decoration: const InputDecoration(labelText: 'Minutes'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: hourlyRateController,
                  decoration: const InputDecoration(labelText: 'Hourly Rate (R)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text('Date: ${DateFormat('yyyy-MM-dd').format(entryDate)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: entryDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDialogState(() => entryDate = picked);
                  },
                ),
                CheckboxListTile(
                  title: const Text('Billable'),
                  value: billable,
                  onChanged: (val) => setDialogState(() => billable = val ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (descController.text.isEmpty || minutesController.text.isEmpty) return;
                
                setState(() => _isLoading = true);
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final userId = prefs.getString('userId') ?? '';

                  await _caseService.createTimeEntry(
                    widget.caseId,
                    CreateCaseTimeEntryRequest(
                      description: descController.text,
                      minutes: int.tryParse(minutesController.text) ?? 0,
                      hourlyRateCents: (double.tryParse(hourlyRateController.text) ?? 0 * 100).toInt(),
                      entryDate: entryDate,
                      billable: billable,
                      userId: userId,
                      taskId: selectedTaskId,
                    ),
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    _fetchEntries();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _entries.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_entries.length} Entries', style: const TextStyle(fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _showAddTimeDialog,
                icon: const Icon(Icons.timer_outlined),
                label: const Text('Capture Time'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _entries.isEmpty 
            ? const Center(child: Text('No time entries found'))
            : ListView.separated(
                itemCount: _entries.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      child: const Icon(Icons.access_time, color: Colors.blue, size: 20),
                    ),
                    title: Text(entry.description),
                    subtitle: Text(
                      '${DateFormat('dd MMM yyyy').format(entry.entryDate)} • ${entry.minutes} mins • ${entry.userName ?? 'Unknown User'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          entry.amountFormatted,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          entry.billable ? (entry.billed ? 'Billed' : 'Unbilled') : 'Non-billable',
                          style: TextStyle(
                            fontSize: 10, 
                            color: entry.billable ? (entry.billed ? Colors.green : Colors.orange) : Colors.grey
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }
}
