import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/services/setting_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class MembershipPolicyConfigurationScreen extends StatefulWidget {
  const MembershipPolicyConfigurationScreen({super.key});

  @override
  State<MembershipPolicyConfigurationScreen> createState() =>
      _MembershipPolicyConfigurationScreenState();
}

class _MembershipPolicyConfigurationScreenState
    extends State<MembershipPolicyConfigurationScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _allowMultipleMemberships = false;
  bool _additionalMembershipRequiresApproval = true;
  bool _allowDeceasedDependentAdd = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _asBoolean(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value?.toString().toLowerCase() == 'true' ||
        value?.toString() == '1';
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final response =
          await ApiClient().get('/v2/membership-policy-configuration');
      if (response.statusCode != 200) throw AppException(response.body);
      final data = Map<String, dynamic>.from(
        jsonDecode(response.body) as Map,
      );
      final settings = await SettingService().getSettings();
      String? deceasedOverride;
      for (final setting in settings) {
        if (setting.type.trim().toUpperCase() == 'MEMBERSHIP' &&
            setting.attribute.trim().toUpperCase() ==
                'ALLOW_DECEASED_DEPENDENT_ADD') {
          deceasedOverride = setting.value;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _allowMultipleMemberships = _asBoolean(
          data['allow_multiple_memberships'] ??
              data['allowMultipleMemberships'],
        );
        _additionalMembershipRequiresApproval = _asBoolean(
          data['additional_membership_requires_approval'] ??
              data['additionalMembershipRequiresApproval'],
        );
        _allowDeceasedDependentAdd = _asBoolean(deceasedOverride);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Could not load membership policy: $error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final response = await ApiClient().put(
        '/v2/membership-policy-configuration',
        body: {
          'allowMultipleMemberships': _allowMultipleMemberships,
          'additionalMembershipRequiresApproval':
              _additionalMembershipRequiresApproval,
        },
      );
      if (response.statusCode != 200) throw AppException(response.body);
      await SettingService().updateSetting(
        'MEMBERSHIP',
        'ALLOW_DECEASED_DEPENDENT_ADD',
        _allowDeceasedDependentAdd ? '1' : '0',
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membership policy saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Could not save membership policy: $error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Membership Policy Configuration')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text(
                          'Allow multiple memberships per member',
                        ),
                        subtitle: const Text(
                          'When disabled, a member cannot receive a second membership.',
                        ),
                        value: _allowMultipleMemberships,
                        onChanged: (value) => setState(() {
                          _allowMultipleMemberships = value;
                          if (!value) {
                            _additionalMembershipRequiresApproval = true;
                          }
                        }),
                      ),
                      SwitchListTile(
                        title: const Text(
                          'Require approval for an additional membership',
                        ),
                        subtitle: const Text(
                          'Creates an approval request and keeps the membership pending until approved.',
                        ),
                        value: _additionalMembershipRequiresApproval,
                        onChanged: _allowMultipleMemberships
                            ? (value) => setState(
                                  () =>
                                      _additionalMembershipRequiresApproval =
                                          value,
                                )
                            : null,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text(
                          'Allow adding a deceased partner as a dependant',
                        ),
                        subtitle: const Text(
                          'Overrides the deceased-partner validation when adding a new dependant. Replacement and removal rules are unchanged, and normal approval rules still apply.',
                        ),
                        value: _allowDeceasedDependentAdd,
                        onChanged: (value) => setState(
                          () => _allowDeceasedDependentAdd = value,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save Configuration'),
                ),
              ],
            ),
    );
  }
}
