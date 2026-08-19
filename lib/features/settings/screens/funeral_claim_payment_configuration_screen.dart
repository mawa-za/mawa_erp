import 'package:flutter/material.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/services/setting_service.dart';
import '../../partners/models/partner.dart';
import '../../partners/partner_service.dart';

class FuneralClaimPaymentConfigurationScreen extends StatefulWidget {
  const FuneralClaimPaymentConfigurationScreen({super.key});

  @override
  State<FuneralClaimPaymentConfigurationScreen> createState() =>
      _FuneralClaimPaymentConfigurationScreenState();
}

class _FuneralClaimPaymentConfigurationScreenState
    extends State<FuneralClaimPaymentConfigurationScreen> {
  static const _settingType = 'FUNERAL_CLAIM_PAY';
  static const _supplierAttribute = 'SUPPLIER_PARTNER_ID';

  bool _loading = true;
  bool _saving = false;
  bool _loadingBanking = false;
  String? _error;
  String? _selectedSupplierId;
  List<Partner> _suppliers = const [];
  List<Map<String, dynamic>> _bankAccounts = const [];

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
      ]);
      final settings = results[0] as List;
      final suppliers = (results[1] as List<Partner>)
        ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

      String? configuredSupplierId;
      for (final setting in settings) {
        if (setting.type == _settingType &&
            setting.attribute == _supplierAttribute &&
            setting.value.toString().trim().isNotEmpty) {
          configuredSupplierId = setting.value.toString().trim();
          break;
        }
      }

      final configuredIsAvailable = configuredSupplierId == null ||
          suppliers.any((supplier) => supplier.id == configuredSupplierId);
      if (!mounted) return;
      setState(() {
        _suppliers = suppliers;
        _selectedSupplierId = configuredIsAvailable ? configuredSupplierId : null;
        if (!configuredIsAvailable) {
          _error =
              'The previously configured funeral claim payment supplier is no longer available as an approved supplier. Select a replacement supplier.';
        }
      });
      await _loadBanking(_selectedSupplierId);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadBanking(String? supplierId) async {
    if (supplierId == null || supplierId.isEmpty) {
      if (mounted) setState(() => _bankAccounts = const []);
      return;
    }
    setState(() => _loadingBanking = true);
    try {
      final accounts = await PartnerService().getSupplierBankAccounts(supplierId);
      if (!mounted) return;
      setState(() => _bankAccounts = accounts);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _bankAccounts = const [];
        _error = friendlyErrorMessage(error);
      });
    } finally {
      if (mounted) setState(() => _loadingBanking = false);
    }
  }

  Future<void> _save() async {
    final supplierId = _selectedSupplierId;
    if (supplierId == null || supplierId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select the supplier to pay for funeral claims.')),
      );
      return;
    }

    final activeBank = _activeBankAccount;
    if (activeBank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The selected supplier must have active approved banking details before it can be used for funeral claim EFT payments.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await SettingService().updateSetting(
        _settingType,
        _supplierAttribute,
        supplierId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Funeral claim payment supplier saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic>? get _activeBankAccount {
    for (final account in _bankAccounts) {
      final status = (account['status'] ?? '').toString().toUpperCase();
      final bankName = (account['bankName'] ?? '').toString().trim();
      final accountNumber = (account['accountNumber'] ?? '').toString().trim();
      final accountType = (account['accountType'] ?? '').toString().trim();
      if (status == 'ACTIVE' &&
          bankName.isNotEmpty &&
          accountNumber.isNotEmpty &&
          accountType.isNotEmpty) {
        return account;
      }
    }
    return null;
  }

  Partner? get _selectedSupplier {
    final id = _selectedSupplierId;
    if (id == null) return null;
    for (final supplier in _suppliers) {
      if (supplier.id == id) return supplier;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Funeral Claim Payments'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Funeral claim EFT supplier',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Configure this separately in every tenant that pays funeral cover claims. For a cross-tenant funeral, the cover-owner tenant uses its own configured Funeral Claim EFT Supplier and that supplier's locally approved banking details. MAWA does not copy the funeral tenant's supplier or banking details into the cover-owner tenant.",
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      if (_error != null) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline_rounded),
                                const SizedBox(width: 12),
                                Expanded(child: Text(_error!)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                value: _suppliers.any(
                                        (supplier) => supplier.id == _selectedSupplierId)
                                    ? _selectedSupplierId
                                    : null,
                                decoration: const InputDecoration(
                                  labelText: 'Funeral claim payment supplier',
                                  helperText:
                                      'Only partners with the Supplier role are available.',
                                  prefixIcon: Icon(Icons.business_outlined),
                                ),
                                isExpanded: true,
                                items: _suppliers
                                    .map(
                                      (supplier) => DropdownMenuItem<String>(
                                        value: supplier.id,
                                        child: Text(
                                          supplier.number.isEmpty
                                              ? supplier.fullName
                                              : '${supplier.fullName} (${supplier.number})',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _saving
                                    ? null
                                    : (value) async {
                                        setState(() {
                                          _selectedSupplierId = value;
                                          _error = null;
                                        });
                                        await _loadBanking(value);
                                      },
                              ),
                              if (_suppliers.isEmpty) ...[
                                const SizedBox(height: 12),
                                const Text(
                                  'No suppliers are available. Create and approve a supplier before configuring funeral claim payments.',
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildBankingCard(theme),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.receipt_long_outlined),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'The cover-owner tenant pays against the invoice generated in the funeral tenant. That invoice number is used as the payment reference. Funeral cover invoices use the same INVOICE number range as the family shortfall invoice.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _saving || _activeBankAccount == null
                              ? null
                              : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(_saving ? 'Saving...' : 'Save configuration'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBankingCard(ThemeData theme) {
    if (_selectedSupplierId == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Select a supplier to view the banking details MAWA will use.'),
        ),
      );
    }
    if (_loadingBanking) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final supplier = _selectedSupplier;
    final account = _activeBankAccount;
    if (account == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${supplier?.fullName ?? 'The selected supplier'} has no complete ACTIVE banking details. Submit and approve the supplier banking details before saving this configuration.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final accountNumber = (account['accountNumber'] ?? '').toString();
    final masked = accountNumber.length > 4
        ? '${'*' * (accountNumber.length - 4)}${accountNumber.substring(accountNumber.length - 4)}'
        : accountNumber;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Banking details used for EFT',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            _detail('Supplier', supplier?.fullName ?? '-'),
            _detail('Bank', (account['bankName'] ?? '-').toString()),
            _detail('Account holder', (account['accountHolder'] ?? '-').toString()),
            _detail('Account number', masked),
            _detail('Account type', (account['accountType'] ?? '-').toString()),
            _detail('Branch code', (account['branchCode'] ?? '-').toString()),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
