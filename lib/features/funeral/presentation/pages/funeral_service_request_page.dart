import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/funeral_api.dart';
import '../../data/models/mortuary_inventory_dto.dart';
import '../../data/models/funeral_package_dto.dart';
import '../../data/models/funeral_membership_cover_dto.dart';
import '../../data/models/funeral_service_request_dto.dart';
import '../../data/models/initiate_funeral_claims_request_dto.dart';
import '../widgets/funeral_package_selector.dart';
import '../widgets/membership_cover_card.dart';
import '../../../../core/widgets/partner_search_dropdown.dart';
import '../../../../core/utils/formatters.dart';

class FuneralServiceRequestPage extends StatefulWidget {
  const FuneralServiceRequestPage({super.key});

  @override
  State<FuneralServiceRequestPage> createState() => _FuneralServiceRequestPageState();
}

class _FuneralServiceRequestPageState extends State<FuneralServiceRequestPage> {
  final _api = FuneralApi();
  int _currentStep = 0;
  bool _isLoading = false;

  // Data
  List<MortuaryInventoryDto> _inventory = [];
  List<FuneralPackageDto> _packages = [];
  List<FuneralMembershipCoverDto> _availableCovers = [];

  // Selections
  MortuaryInventoryDto? _selectedDeceased;
  final _idNumberController = TextEditingController();
  DateTime _funeralDate = DateTime.now().add(const Duration(days: 3));
  final _locationController = TextEditingController();
  String? _familyRepPartnerId;
  FuneralPackageDto? _selectedPackage;
  final List<FuneralExtraDto> _extras = [];
  final List<String> _selectedMembershipIds = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getMortuaryInventory(),
        _api.getFuneralPackages(),
      ]);
      setState(() {
        _inventory = results[0] as List<MortuaryInventoryDto>;
        _packages = results[1] as List<FuneralPackageDto>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  Future<void> _checkMembership() async {
    if (_idNumberController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final covers = await _api.checkMembership(_idNumberController.text);
      setState(() {
        _availableCovers = covers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error checking membership: $e')));
      }
    }
  }

  Future<void> _createServiceRequest() async {
    if (_selectedDeceased == null || _selectedPackage == null || _familyRepPartnerId == null) return;

    setState(() => _isLoading = true);
    try {
      final request = FuneralServiceRequestDto(
        mortuaryInventoryId: _selectedDeceased!.id,
        deceasedName: _selectedDeceased!.deceasedName,
        deceasedIdentityNumber: _idNumberController.text,
        funeralDate: _funeralDate,
        funeralLocation: _locationController.text,
        familyRepPartnerId: _familyRepPartnerId!,
        packageId: _selectedPackage!.id,
        extras: _extras,
      );

      final created = await _api.createServiceRequest(request);
      
      if (_selectedMembershipIds.isNotEmpty) {
        await _api.initiateClaims(
          created.id!,
          InitiateFuneralClaimsRequestDto(membershipIds: _selectedMembershipIds),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Funeral Arrangement Saved')));
        context.pushReplacement('/funeral/service-request/${created.id}/invoice-preview');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Funeral Arrangement')),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Stepper(
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep == 0 && (_selectedDeceased == null || _idNumberController.text.isEmpty)) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select deceased and enter ID')));
                   return;
                }
                if (_currentStep == 2 && _selectedPackage == null) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a package')));
                   return;
                }
                
                if (_currentStep < 4) {
                  setState(() => _currentStep += 1);
                } else {
                  _createServiceRequest();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) setState(() => _currentStep -= 1);
              },
              steps: [
                Step(
                  title: const Text('Deceased Details'),
                  isActive: _currentStep >= 0,
                  content: Column(
                    children: [
                      DropdownButtonFormField<MortuaryInventoryDto>(
                        value: _selectedDeceased,
                        decoration: const InputDecoration(labelText: 'Select Deceased from Mortuary', border: OutlineInputBorder()),
                        items: _inventory.map((i) => DropdownMenuItem(value: i, child: Text(i.deceasedName))).toList(),
                        onChanged: (v) => setState(() => _selectedDeceased = v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _idNumberController,
                        decoration: const InputDecoration(labelText: 'Deceased Identity Number', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Funeral Details'),
                  isActive: _currentStep >= 1,
                  content: Column(
                    children: [
                      ListTile(
                        title: const Text('Funeral Date'),
                        subtitle: Text(Formatters.formatDate(_funeralDate)),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _funeralDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) setState(() => _funeralDate = date);
                        },
                      ),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(labelText: 'Funeral Location / Area', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      PartnerSearchDropdown(
                        role: 'CUSTOMER',
                        label: 'Family Representative',
                        onPartnerSelected: (p) => setState(() => _familyRepPartnerId = p?.id),
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Package & Extras'),
                  isActive: _currentStep >= 2,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FuneralPackageSelector(
                        packages: _packages,
                        selectedPackage: _selectedPackage,
                        onSelected: (p) => setState(() => _selectedPackage = p),
                      ),
                      const Divider(height: 32),
                      const Text('Extras', style: TextStyle(fontWeight: FontWeight.bold)),
                      ..._extras.map((e) => ListTile(
                        title: Text(e.description),
                        trailing: Text(Formatters.formatCentsAsRand(e.amountCents)),
                        onLongPress: () => setState(() => _extras.remove(e)),
                      )),
                      TextButton.icon(
                        onPressed: _showAddExtraDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Extra'),
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Membership Check'),
                  isActive: _currentStep >= 3,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(onPressed: _checkMembership, child: const Text('Check for Available Cover')),
                      const SizedBox(height: 16),
                      if (_availableCovers.isEmpty) const Text('No active memberships found for this ID.'),
                      ..._availableCovers.map((cover) => MembershipCoverCard(
                        cover: cover,
                        isSelected: _selectedMembershipIds.contains(cover.membershipId ?? cover.sourceReference),
                        onTap: () {
                          final id = cover.membershipId ?? cover.sourceReference;
                          if (id == null) return;
                          setState(() {
                            if (_selectedMembershipIds.contains(id)) {
                              _selectedMembershipIds.remove(id);
                            } else {
                              _selectedMembershipIds.add(id);
                            }
                          });
                        },
                      )),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Review'),
                  isActive: _currentStep >= 4,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Deceased: ${_selectedDeceased?.deceasedName ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Funeral: ${Formatters.formatDate(_funeralDate)} at ${_locationController.text}'),
                      Text('Package: ${_selectedPackage?.name ?? 'N/A'}'),
                      Text('Selected Claims: ${_selectedMembershipIds.length}'),
                      const SizedBox(height: 16),
                      const Text('Total Estimate:', style: TextStyle(fontSize: 16)),
                      Text(
                        Formatters.formatCentsAsRand((_selectedPackage?.basePriceCents ?? 0) + _extras.fold(0, (sum, e) => sum + e.amountCents)),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _showAddExtraDialog() {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Extra'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
            TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount (Rand)'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final cents = (double.tryParse(amountController.text) ?? 0 * 100).toInt();
              setState(() => _extras.add(FuneralExtraDto(description: descController.text, amountCents: cents)));
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}
