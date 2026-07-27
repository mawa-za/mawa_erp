import 'package:flutter/material.dart';
import '../../../core/models/setting.dart';
import '../../../core/services/setting_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  bool _isLoading = true;
  List<Setting> _settings = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final settings = await SettingService().getSettings();
      if (mounted) {
        setState(() {
          _settings = settings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  Map<String, List<Setting>> _groupSettings() {
    final Map<String, List<Setting>> groups = {};
    for (var setting in _settings) {
      if (!groups.containsKey(setting.type)) {
        groups[setting.type] = [];
      }
      groups[setting.type]!.add(setting);
    }
    return groups;
  }

  IconData _getIconForType(String type) {
    switch (type.toUpperCase()) {
      case 'TENANT':
        return Icons.business_outlined;
      case 'CASH-BANK-ACCOUNT':
      case 'EFT-BANK-ACCOUNT':
        return Icons.account_balance_outlined;
      case 'WAREHOUSE-LAYOUT':
        return Icons.warehouse_outlined;
      case 'FNB-API':
        return Icons.api_outlined;
      case 'GROCERY-CLAIM':
      case 'FUNERAL-CLAIM':
      case 'TOMBSTONE-CLAIM':
        return Icons.request_quote_outlined;
      case 'XERO':
      case 'INVOICE':
        return Icons.receipt_long_outlined;
      case 'BANK-PAYMENT-FILE':
        return Icons.file_present_outlined;
      default:
        return Icons.settings_outlined;
    }
  }

  Future<void> _editSetting(Setting setting) async {
    final controller = TextEditingController(text: setting.value);
    final colorScheme = Theme.of(context).colorScheme;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(_getIconForType(setting.type), color: colorScheme.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text('Edit ${setting.attribute}', style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: ${setting.type}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              autofocus: true,
              maxLines: null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != null && result != setting.value) {
      try {
        await SettingService().updateSetting(setting.type, setting.attribute, result);
        _fetchSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Setting updated successfully'), behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyErrorMessage('Error: $e')), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  Future<void> _addNewSetting(String type) async {
    final attributeController = TextEditingController();
    final valueController = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.add_circle_outline, color: colorScheme.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text('Add $type Setting', style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: attributeController,
              decoration: InputDecoration(
                labelText: 'Attribute Name',
                hintText: 'e.g. TIMEOUT',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: valueController,
              decoration: InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            onPressed: () {
              if (attributeController.text.isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('ADD SETTING', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await SettingService().updateSetting(
          type,
          attributeController.text.trim().toUpperCase(),
          valueController.text.trim(),
        );
        _fetchSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New setting added'), behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyErrorMessage('Error: $e')), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('System Settings', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _fetchSettings,
                tooltip: 'Refresh settings',
              ),
              const SizedBox(width: 8),
            ],
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            centerTitle: false,
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: colorScheme.error.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text('Failed to load settings', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _fetchSettings,
                        icon: const Icon(Icons.refresh),
                        label: const Text('RETRY'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_settings.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('No settings found.')),
            )
          else
            _buildSettingsList(colorScheme),
        ],
      ),
    );
  }

  Widget _buildSettingsList(ColorScheme colorScheme) {
    final grouped = _groupSettings();
    final sortedTypes = grouped.keys.toList()..sort();

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final type = sortedTypes[index];
            final typeSettings = grouped[type]!;
            return _buildCategoryCard(type, typeSettings, colorScheme);
          },
          childCount: sortedTypes.length,
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String type, List<Setting> settings, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getIconForType(type), color: colorScheme.primary, size: 20),
          ),
          title: Text(
            type.replaceAll('-', ' '),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Text('${settings.length} parameters', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          trailing: IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 22),
            color: colorScheme.primary,
            onPressed: () => _addNewSetting(type),
            tooltip: 'Add parameter to this group',
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Divider(height: 1),
            ...settings.map((s) => _buildSettingTile(s, colorScheme)),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile(Setting s, ColorScheme colorScheme) {
    return InkWell(
      onTap: () => _editSetting(s),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.attribute.replaceAll('-', ' '),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.value.isEmpty ? 'Not set' : s.value,
                    style: TextStyle(
                      fontSize: 14,
                      color: s.value.isEmpty ? Colors.grey[400] : Colors.black87,
                      fontStyle: s.value.isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit_outlined, size: 18, color: colorScheme.primary.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}
