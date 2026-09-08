import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/services/setting_service.dart';
import '../../partners/models/partner.dart';
import '../../partners/partner_service.dart';
import '../../payments/screens/payment_account_configuration_screen.dart';

class GroupSocietySettlementConfigurationScreen extends StatefulWidget {
  const GroupSocietySettlementConfigurationScreen({super.key});

  @override
  State<GroupSocietySettlementConfigurationScreen> createState() =>
      _GroupSocietySettlementConfigurationScreenState();
}

class _GroupSocietySettlementConfigurationScreenState
    extends State<GroupSocietySettlementConfigurationScreen> {
  static const _settingType = 'GROUP_SOCIETY_SETTLEMENT';
  static const _ledgerOnly = 'LEDGER_ONLY';
  static const _internalTransfer = 'INTERNAL_ACCOUNT_TRANSFER';
  static const _externalPayment = 'EXTERNAL_PROVIDER_PAYMENT';

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _mode = _ledgerOnly;
  String? _recipientPartnerId;
  List<Partner> _suppliers = const [];
  List<Map<String, dynamic>> _recipientAccounts = const [];
  Map<String, dynamic>? _sourceAccount;

  bool get _usesFnb => _mode != _ledgerOnly;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        SettingService().getSettings(),
        PartnerService().getPartnersByRole('SUPPLIER'),
        ApiClient().get('/v2/payment-account-configuration'),
      ]);
      final settings = results[0] as List;
      final suppliers = (results[1] as List<Partner>)
        ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
      final accountResponse = results[2] as dynamic;
      if (accountResponse.statusCode != 200) {
        throw AppException(accountResponse.body);
      }
      final paymentAccounts = (jsonDecode(accountResponse.body) as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      String mode = _ledgerOnly;
      String? recipient;
      for (final setting in settings) {
        if (setting.type != _settingType) continue;
        if (setting.attribute == 'MODE' && setting.value.toString().trim().isNotEmpty) {
          mode = setting.value.toString().trim().toUpperCase();
        }
        if (setting.attribute == 'RECIPIENT_PARTNER_ID' &&
            setting.value.toString().trim().isNotEmpty) {
          recipient = setting.value.toString().trim();
        }
      }
      final source = _firstWhereOrNull(
        paymentAccounts,
        (row) => row['account_role'] == 'DEBTOR' &&
            row['request_type'] == 'GROUP_SOCIETY_SETTLEMENT' &&
            _active(row),
      );
      if (!mounted) return;
      setState(() {
        _mode = {_ledgerOnly, _internalTransfer, _externalPayment}.contains(mode)
            ? mode
            : _ledgerOnly;
        _suppliers = suppliers;
        _recipientPartnerId = suppliers.any((supplier) => supplier.id == recipient)
            ? recipient
            : null;
        _sourceAccount = source;
      });
      await _loadRecipientBanking(_recipientPartnerId);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRecipientBanking(String? partnerId) async {
    if (partnerId == null) {
      if (mounted) setState(() => _recipientAccounts = const []);
      return;
    }
    try {
      final rows = await PartnerService().getSupplierBankAccounts(partnerId);
      if (mounted) setState(() => _recipientAccounts = rows);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    }
  }

  Future<void> _save() async {
    if (_usesFnb) {
      if (_sourceAccount == null) {
        _show('Configure an active FNB debtor account for Group Society Settlement.');
        return;
      }
      if ((_sourceAccount!['bank_integration'] ?? '').toString().toUpperCase() != 'FNB') {
        _show('The Group Society Settlement source account must use FNB integration.');
        return;
      }
      if (_recipientPartnerId == null || _activeRecipientAccount == null) {
        _show('Select a recipient with active approved banking details.');
        return;
      }
      if (_digits(_sourceAccount!['account_number']) ==
          _digits(_activeRecipientAccount!['accountNumber'])) {
        _show('The source and destination accounts are the same. Select Ledger only.');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      await SettingService().updateSetting(_settingType, 'MODE', _mode);
      await SettingService().updateSetting(
        _settingType,
        'RECIPIENT_PARTNER_ID',
        _usesFnb ? _recipientPartnerId! : '',
      );
      if (!mounted) return;
      _show('Group society settlement configuration saved.');
    } catch (error) {
      if (mounted) _show(friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic>? get _activeRecipientAccount => _firstWhereOrNull(
        _recipientAccounts,
        (row) => (row['status'] ?? '').toString().toUpperCase() == 'ACTIVE' &&
            _digits(row['accountNumber']).isNotEmpty,
      );

  T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T) test) {
    for (final value in values) {
      if (test(value)) return value;
    }
    return null;
  }

  bool _active(Map<String, dynamic> row) =>
      row['active'] == true || row['active'] == 1;
  String _digits(Object? value) =>
      (value ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
  String _mask(Object? value) {
    final number = _digits(value);
    return number.length <= 4
        ? number
        : '${'*' * (number.length - 4)}${number.substring(number.length - 4)}';
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Society Settlement'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Choose how approved group society funeral cover is settled.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!))),
                RadioListTile<String>(
                  value: _ledgerOnly,
                  groupValue: _mode,
                  title: const Text('Ledger only'),
                  subtitle: const Text('Deduct the group society balance and settle the invoice without a bank transfer.'),
                  onChanged: (value) => setState(() => _mode = value!),
                ),
                RadioListTile<String>(
                  value: _internalTransfer,
                  groupValue: _mode,
                  title: const Text('Internal account transfer'),
                  subtitle: const Text('Pay from the ring-fenced FNB group society funds account into the tenant invoice payments account.'),
                  onChanged: (value) => setState(() => _mode = value!),
                ),
                RadioListTile<String>(
                  value: _externalPayment,
                  groupValue: _mode,
                  title: const Text('External provider payment'),
                  subtitle: const Text('Pay from the ring-fenced FNB group society funds account to an external funeral provider.'),
                  onChanged: (value) => setState(() => _mode = value!),
                ),
                if (_usesFnb) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.account_balance),
                      title: const Text('FNB source account'),
                      subtitle: Text(_sourceAccount == null
                          ? 'No active GROUP_SOCIETY_SETTLEMENT debtor account configured.'
                          : '${_sourceAccount!['account_holder']} • ${_mask(_sourceAccount!['account_number'])}'),
                      trailing: TextButton(
                        onPressed: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentAccountConfigurationScreen()));
                          await _load();
                        },
                        child: const Text('Configure'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _recipientPartnerId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _mode == _internalTransfer
                          ? 'Tenant invoice payments account recipient'
                          : 'External funeral provider recipient',
                      helperText: 'Recipients must be approved suppliers with active banking details.',
                      border: const OutlineInputBorder(),
                    ),
                    items: _suppliers.map((supplier) => DropdownMenuItem(
                      value: supplier.id,
                      child: Text(supplier.fullName, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (value) async {
                      setState(() => _recipientPartnerId = value);
                      await _loadRecipientBanking(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: const Text('Destination account'),
                    subtitle: Text(_activeRecipientAccount == null
                        ? 'No active approved banking details found.'
                        : '${_activeRecipientAccount!['bankName']} • ${_mask(_activeRecipientAccount!['accountNumber'])}'),
                  ),
                ],
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save configuration'),
                  ),
                ),
              ],
            ),
    );
  }
}
