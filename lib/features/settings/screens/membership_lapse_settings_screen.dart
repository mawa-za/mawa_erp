import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';

class MembershipLapseSettingsScreen extends StatefulWidget {
  const MembershipLapseSettingsScreen({super.key});

  @override
  State<MembershipLapseSettingsScreen> createState() =>
      _MembershipLapseSettingsScreenState();
}

class _MembershipLapseSettingsScreenState
    extends State<MembershipLapseSettingsScreen> {
  bool _enabled = true;
  int _missedPremiumsBeforeLapse = 3;
  bool _loading = true;
  bool _saving = false;
  bool _running = false;
  String? _lastRunAt;
  int _lastLapsedCount = 0;
  String? _pageError;
  Map<String, dynamic>? _lastRunResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _pageError = null;
    });

    try {
      final response =
          await ApiClient().get('/v2/membership-lapse/configuration');
      if (!_isSuccessful(response.statusCode)) {
        throw Exception(_errorMessage(response.body, response.statusCode));
      }

      final data = _decodeObject(response.body);
      if (!mounted) return;
      setState(() {
        _enabled = _asBool(data['enabled'], fallback: true);
        _missedPremiumsBeforeLapse = _asInt(
          data['missedPremiumsBeforeLapse'],
          fallback: 3,
        ).clamp(1, 24).toInt();
        _lastRunAt = data['lastRunAt']?.toString();
        _lastLapsedCount = _asInt(data['lastLapsedCount']);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _pageError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _running) return;
    setState(() => _saving = true);

    try {
      final response = await ApiClient().put(
        '/v2/membership-lapse/configuration',
        body: {
          'enabled': _enabled,
          'missedPremiumsBeforeLapse': _missedPremiumsBeforeLapse,
        },
      );
      if (!_isSuccessful(response.statusCode)) {
        throw Exception(_errorMessage(response.body, response.statusCode));
      }

      final data = _decodeObject(response.body);
      if (!mounted) return;
      setState(() {
        _lastRunAt = data['lastRunAt']?.toString();
        _lastLapsedCount = _asInt(data['lastLapsedCount']);
      });
      _showMessage('Membership lapse configuration saved.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _runNow() async {
    if (_saving || _running) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Evaluate memberships now?'),
        content: Text(
          'Active memberships with at least '
          '$_missedPremiumsBeforeLapse consecutive overdue, outstanding '
          'premium(s) will be changed to LAPSED. Paid premiums do not count.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RUN'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _running = true;
      _lastRunResult = null;
    });

    try {
      final response =
          await ApiClient().post('/v2/membership-lapse/run-now');
      if (!_isSuccessful(response.statusCode)) {
        throw Exception(_errorMessage(response.body, response.statusCode));
      }

      final result = _decodeObject(response.body);
      if (!mounted) return;
      setState(() {
        _lastRunResult = result;
        _lastRunAt = DateTime.now().toIso8601String();
        _lastLapsedCount = _asInt(result['lapsedMemberships']);
      });
      _showMessage(
        'Evaluation completed: ${_asInt(result['lapsedMemberships'])} '
        'membership(s) lapsed.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Membership Lapse Configuration')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_pageError != null) ...[
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _pageError!,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('RETRY'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _enabled,
                            onChanged: _saving || _running
                                ? null
                                : (value) => setState(() => _enabled = value),
                            title: const Text('Enable automatic membership lapse'),
                            subtitle: const Text(
                              'The tenant-aware membership lapse job applies this policy.',
                            ),
                          ),
                          const Divider(),
                          DropdownButtonFormField<int>(
                            value: _missedPremiumsBeforeLapse,
                            decoration: const InputDecoration(
                              labelText: 'Missed premiums before lapse',
                              border: OutlineInputBorder(),
                              helperText:
                                  'Only consecutive overdue premiums with an outstanding balance count.',
                            ),
                            items: List.generate(
                              24,
                              (index) => DropdownMenuItem<int>(
                                value: index + 1,
                                child: Text(
                                  '${index + 1} premium${index == 0 ? '' : 's'}',
                                ),
                              ),
                            ),
                            onChanged: _saving || _running
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(
                                        () => _missedPremiumsBeforeLapse = value,
                                      );
                                    }
                                  },
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _saving || _running ? null : _save,
                              icon: _saving
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(
                                _saving ? 'SAVING...' : 'SAVE CONFIGURATION',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Run membership lapse evaluation',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Run the configured policy immediately. Every lapsed '
                            'membership is recorded in the membership change audit trail.',
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _saving || _running ? null : _runNow,
                              icon: _running
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.play_arrow_outlined),
                              label: Text(
                                _running ? 'EVALUATING...' : 'EVALUATE NOW',
                              ),
                            ),
                          ),
                          if (_lastRunResult != null) ...[
                            const SizedBox(height: 16),
                            _ResultRow(
                              label: 'Memberships evaluated',
                              value: _asInt(
                                _lastRunResult!['evaluatedMemberships'],
                              ).toString(),
                            ),
                            const SizedBox(height: 8),
                            _ResultRow(
                              label: 'With overdue premiums',
                              value: _asInt(
                                _lastRunResult![
                                    'membershipsWithOverduePremiums'],
                              ).toString(),
                            ),
                            const SizedBox(height: 8),
                            _ResultRow(
                              label: 'Memberships lapsed',
                              value: _asInt(
                                _lastRunResult!['lapsedMemberships'],
                              ).toString(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Automatic lapse status',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          _ResultRow(
                            label: 'Last run',
                            value: _formatDateTime(_lastRunAt),
                          ),
                          const SizedBox(height: 8),
                          _ResultRow(
                            label: 'Lapsed in last run',
                            value: _lastLapsedCount.toString(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  bool _isSuccessful(int statusCode) =>
      statusCode >= 200 && statusCode < 300;

  Map<String, dynamic> _decodeObject(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('The server returned an unexpected response.');
  }

  String _errorMessage(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final message =
            decoded['message'] ?? decoded['error'] ?? decoded['reason'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }
    } catch (_) {
      // Fall back to the response body below.
    }
    final trimmed = body.trim();
    if (trimmed.isNotEmpty && !trimmed.startsWith('<')) return trimmed;
    return 'Membership lapse request failed with HTTP $statusCode.';
  }

  int _asInt(Object? value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool _asBool(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes' || text == 'y') {
      return true;
    }
    if (text == 'false' || text == '0' || text == 'no' || text == 'n') {
      return false;
    }
    return fallback;
  }

  String _formatDateTime(String? value) {
    if (value == null || value.trim().isEmpty) return 'Never';
    try {
      final date = DateTime.parse(value).toLocal();
      return '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value;
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
          textAlign: TextAlign.end,
        ),
      ],
    );
  }
}
