import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class PremiumGenerationSettingsScreen extends StatefulWidget {
  const PremiumGenerationSettingsScreen({super.key});

  @override
  State<PremiumGenerationSettingsScreen> createState() =>
      _PremiumGenerationSettingsScreenState();
}

class _PremiumGenerationSettingsScreenState
    extends State<PremiumGenerationSettingsScreen> {
  static const String _dayOfMonthMode = 'DAY_OF_MONTH';
  static const String _monthAfterLastPaymentMode =
      'MONTH_AFTER_LAST_PAYMENT';

  String _mode = _dayOfMonthMode;
  int _generationDay = 1;
  bool _enabled = true;
  bool _loading = true;
  bool _saving = false;
  bool _backfilling = false;
  String? _lastRunAt;
  String? _lastGeneratedPeriod;
  String? _pageError;
  Map<String, dynamic>? _lastBackfillResult;

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
          await ApiClient().get('/v2/premium-generation/configuration');
      if (!_isSuccessful(response.statusCode)) {
        throw AppException(_errorMessage(response.body, response.statusCode));
      }

      final data = _decodeObject(response.body);
      final rawMode = (data['generationMode'] ??
              data['generation_mode'] ??
              _dayOfMonthMode)
          .toString()
          .toUpperCase();
      final configuredDay = _asInt(
        data['generationDayOfMonth'] ?? data['generation_day_of_month'],
        fallback: 1,
      );

      if (!mounted) return;
      setState(() {
        _mode = rawMode == 'FIRST_DAY_OF_MONTH'
            ? _dayOfMonthMode
            : rawMode;
        _generationDay = configuredDay.clamp(1, 31).toInt();
        _enabled = _asBool(data['enabled'], fallback: true);
        _lastRunAt =
            (data['lastRunAt'] ?? data['last_run_at'])?.toString();
        _lastGeneratedPeriod =
            (data['lastGeneratedPeriod'] ?? data['last_generated_period'])
                ?.toString();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _pageError = friendlyErrorMessage(error);
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _backfilling) return;
    setState(() => _saving = true);

    try {
      final response = await ApiClient().put(
        '/v2/premium-generation/configuration',
        body: {
          'generationMode': _mode,
          'generationDayOfMonth': _generationDay,
          'enabled': _enabled,
        },
      );
      if (!_isSuccessful(response.statusCode)) {
        throw AppException(_errorMessage(response.body, response.statusCode));
      }

      final data = _decodeObject(response.body);
      if (!mounted) return;
      setState(() {
        _lastRunAt =
            (data['lastRunAt'] ?? data['last_run_at'])?.toString();
        _lastGeneratedPeriod =
            (data['lastGeneratedPeriod'] ?? data['last_generated_period'])
                ?.toString();
      });
      _showMessage('Automatic premium generation configuration saved.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        friendlyErrorMessage(error),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _backfill() async {
    if (_saving || _backfilling) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate missing premiums?'),
        content: const Text(
          'This will generate only missing premium rows for the current period '
          'and the previous five periods. Existing premiums will not be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('GENERATE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _backfilling = true;
      _lastBackfillResult = null;
    });

    try {
      final response = await ApiClient()
          .post('/v2/premium-generation/backfill-six-periods');
      if (!_isSuccessful(response.statusCode)) {
        throw AppException(_errorMessage(response.body, response.statusCode));
      }

      final result = _decodeObject(response.body);
      if (!mounted) return;
      setState(() => _lastBackfillResult = result);

      final created = _asInt(result['created']);
      final alreadyPresent = _asInt(result['alreadyPresent']);
      final skipped = _asInt(result['skippedMissingPremiumAmount']);
      _showMessage(
        'Backfill completed: $created created, $alreadyPresent already existed'
        '${skipped > 0 ? ', $skipped skipped because no premium amount was configured' : ''}.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        friendlyErrorMessage(error),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _backfilling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Automatic Premium Generation')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_pageError != null) ...[
                    _ErrorCard(message: _pageError!, onRetry: _load),
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
                            onChanged: _saving || _backfilling
                                ? null
                                : (value) =>
                                    setState(() => _enabled = value),
                            title: const Text('Enable automatic generation'),
                            subtitle: const Text(
                              'The tenant-aware scheduler checks this configuration hourly.',
                            ),
                          ),
                          const Divider(),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: _dayOfMonthMode,
                            groupValue: _mode,
                            onChanged: _saving || _backfilling
                                ? null
                                : (value) =>
                                    setState(() => _mode = value!),
                            title: const Text(
                              'Generate on a selected day each month',
                            ),
                            subtitle: const Text(
                              'Creates the current period once the selected day is reached.',
                            ),
                          ),
                          if (_mode == _dayOfMonthMode)
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: DropdownButtonFormField<int>(
                                value: _generationDay,
                                decoration: const InputDecoration(
                                  labelText: 'Automatic generation day',
                                  border: OutlineInputBorder(),
                                  helperText:
                                      'For shorter months, day 29–31 runs on the last day.',
                                ),
                                items: List.generate(
                                  31,
                                  (index) => DropdownMenuItem<int>(
                                    value: index + 1,
                                    child: Text(_ordinal(index + 1)),
                                  ),
                                ),
                                onChanged: _saving || _backfilling
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setState(
                                            () => _generationDay = value,
                                          );
                                        }
                                      },
                              ),
                            ),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: _monthAfterLastPaymentMode,
                            groupValue: _mode,
                            onChanged: _saving || _backfilling
                                ? null
                                : (value) =>
                                    setState(() => _mode = value!),
                            title: const Text(
                              'Generate one month after the last paid period',
                            ),
                            subtitle: const Text(
                              'Keeps one next premium available based on Paid Up To.',
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _saving || _backfilling ? null : _save,
                              icon: _saving
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(
                                _saving
                                    ? 'SAVING...'
                                    : 'SAVE CONFIGURATION',
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
                            'Repair missing periods',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Generate missing premiums for the current period and '
                            'the previous five periods. The operation is idempotent '
                            'and does not replace existing premium rows.',
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed:
                                  _saving || _backfilling ? null : _backfill,
                              icon: _backfilling
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.history_outlined),
                              label: Text(
                                _backfilling
                                    ? 'GENERATING...'
                                    : 'GENERATE MISSING PREMIUMS FOR PAST 6 PERIODS',
                              ),
                            ),
                          ),
                          if (_lastBackfillResult != null) ...[
                            const SizedBox(height: 16),
                            _BackfillResultCard(result: _lastBackfillResult!),
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
                            'Automatic generation status',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          _StatusRow(
                            label: 'Last automatic run',
                            value: _formatDateTime(_lastRunAt),
                          ),
                          const SizedBox(height: 8),
                          _StatusRow(
                            label: 'Last generated period',
                            value: _formatPeriod(_lastGeneratedPeriod),
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

  bool _isSuccessful(int statusCode) => statusCode >= 200 && statusCode < 300;

  Map<String, dynamic> _decodeObject(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('The server returned an unexpected response.');
  }

  String _errorMessage(String body, int statusCode) {
    return friendlyErrorMessage(
      body,
      statusCode: statusCode,
      fallback: 'The premium generation request could not be completed. Please try again.',
    );
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

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  static String _ordinal(int day) {
    final remainder100 = day % 100;
    if (remainder100 >= 11 && remainder100 <= 13) return '${day}th';
    return switch (day % 10) {
      1 => '${day}st',
      2 => '${day}nd',
      3 => '${day}rd',
      _ => '${day}th',
    };
  }

  static String _formatDateTime(String? value) {
    if (value == null || value.trim().isEmpty) return 'Not run yet';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static String _formatPeriod(String? value) {
    if (value == null || value.length != 6) return 'Not generated yet';
    return '${value.substring(0, 4)}-${value.substring(4, 6)}';
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            TextButton(onPressed: () => onRetry(), child: const Text('RETRY')),
          ],
        ),
      ),
    );
  }
}

class _BackfillResultCard extends StatelessWidget {
  const _BackfillResultCard({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final periods = result['periods'] is List
        ? (result['periods'] as List).map((value) => value.toString()).join(', ')
        : '${result['fromPeriod'] ?? ''} – ${result['toPeriod'] ?? ''}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Created: ${result['created'] ?? 0}'),
          Text('Already present: ${result['alreadyPresent'] ?? 0}'),
          Text(
            'Skipped without premium amount: '
            '${result['skippedMissingPremiumAmount'] ?? 0}',
          ),
          if (periods.trim().isNotEmpty) Text('Periods: $periods'),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 170,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
