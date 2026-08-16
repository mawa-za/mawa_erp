import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/utils/app_date_utils.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class SchedulerConfigurationScreen extends StatefulWidget {
  const SchedulerConfigurationScreen({super.key});

  @override
  State<SchedulerConfigurationScreen> createState() => _SchedulerConfigurationScreenState();
}

class _SchedulerConfigurationScreenState extends State<SchedulerConfigurationScreen> {
  final _api = ApiClient();
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _jobs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _api.get('/v2/scheduler/jobs');
      if (response.statusCode != 200) throw AppException(response.body);
      final decoded = jsonDecode(response.body) as List;
      _jobs = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Failed to load schedules: $e'))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(Map<String, dynamic> job) async {
    setState(() => _saving = true);
    try {
      final code = job['jobCode'];
      final response = await _api.put('/v2/scheduler/jobs/$code', body: job);
      if (response.statusCode != 200) throw AppException(response.body);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Failed to save schedule: $e'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _runNow(Map<String, dynamic> job) async {
    setState(() => _saving = true);
    try {
      final code = job['jobCode'];
      final response = await _api.post('/v2/scheduler/jobs/$code/run-now');
      if (response.statusCode != 200) throw AppException(response.body);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job triggered')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Failed to run job: $e'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduler Configuration'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
              ? const Center(child: Text('No scheduled jobs configured.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _jobs.length,
                  itemBuilder: (context, index) => _buildJobCard(_jobs[index]),
                ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final enabled = job['enabled'] == true;
    final isDailyTimeJob = job['runTime'] != null;
    final intervalController = TextEditingController(text: (job['intervalMinutes'] ?? 1440).toString());
    final runTimeController = TextEditingController(text: (job['runTime'] ?? '00:00').toString());
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job['name']?.toString() ?? job['jobCode'].toString(), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(job['description']?.toString() ?? '', style: TextStyle(color: Colors.grey[700])),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: _saving ? null : (value) {
                    job['enabled'] = value;
                    _save(job);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: isDailyTimeJob
                      ? TextFormField(
                          controller: runTimeController,
                          decoration: const InputDecoration(
                            labelText: 'Run time (HH:mm)',
                            hintText: '00:00',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => job['runTime'] = value.trim(),
                        )
                      : TextFormField(
                          controller: intervalController,
                          decoration: const InputDecoration(labelText: 'Interval minutes', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => job['intervalMinutes'] = int.tryParse(value) ?? job['intervalMinutes'],
                        ),
                ),
                ElevatedButton.icon(
                  onPressed: _saving ? null : () => _save(job),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _runNow(job),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Run now'),
                ),
                Text('Last: ${job['lastRunAt'] == null ? 'Never' : AppDateUtils.displayDateTime(job['lastRunAt'])}'),
                Text('Next: ${job['nextRunAt'] == null ? 'Stopped' : AppDateUtils.displayDateTime(job['nextRunAt'])}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
