import 'package:flutter/material.dart';
import '../../data/funeral_api.dart';
import '../../data/models/mortuary_inventory_dto.dart';
import '../../data/models/mortuary_checkout_request_dto.dart';
import '../../data/models/funeral_enums.dart';
import '../widgets/funeral_status_chip.dart';
import '../../../../core/utils/formatters.dart';

class MortuaryInventoryPage extends StatefulWidget {
  const MortuaryInventoryPage({super.key});

  @override
  State<MortuaryInventoryPage> createState() => _MortuaryInventoryPageState();
}

class _MortuaryInventoryPageState extends State<MortuaryInventoryPage> {
  final _api = FuneralApi();
  List<MortuaryInventoryDto> _inventory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final inventory = await _api.getMortuaryInventory();
      if (!mounted) return;
      setState(() {
        _inventory = inventory;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading inventory: $e')),
      );
    }
  }

  Future<void> _checkout(MortuaryInventoryDto item) async {
    final formKey = GlobalKey<FormState>();
    final releaseToController = TextEditingController();
    final idNumberController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Checkout: ${item.deceasedName}'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: releaseToController,
                    decoration: const InputDecoration(labelText: 'Release To'),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: idNumberController,
                    decoration: const InputDecoration(labelText: 'Identity Number'),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Checkout Date'),
                    subtitle: Text(Formatters.formatDateTime(selectedDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDate),
                        );
                        if (time != null) {
                          setDialogState(() {
                            selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                          });
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Checkout'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        await _api.checkoutFromMortuary(
          item.id,
          MortuaryCheckoutRequestDto(
            releaseTo: releaseToController.text,
            identityNumber: idNumberController.text,
            checkoutDate: selectedDate,
          ),
        );
        await _loadInventory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully checked out')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mortuary Inventory'),
        actions: [
          IconButton(onPressed: _loadInventory, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _inventory.isEmpty
              ? const Center(child: Text('No deceased in inventory'))
              : ListView.builder(
                  itemCount: _inventory.length,
                  itemBuilder: (context, index) {
                    final item = _inventory[index];
                    return ListTile(
                      title: Text(
                        item.deceasedName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Tag: ${item.tagNumber ?? 'N/A'} • In: ${Formatters.formatFriendlyDate(item.checkInDate)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FuneralStatusChip(status: item.status),
                          if (item.status == MortuaryStatus.IN_MORTUARY || item.status == MortuaryStatus.IN_STORAGE)
                            IconButton(
                              icon: const Icon(Icons.output, color: Colors.red),
                              onPressed: () => _checkout(item),
                              tooltip: 'Checkout',
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
