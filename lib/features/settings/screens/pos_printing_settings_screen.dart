import 'package:flutter/material.dart';
import '../models/pos_printing_models.dart';
import '../services/pos_printing_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';
import 'pos_print_job_monitor_screen.dart';

class PosPrintingSettingsScreen extends StatefulWidget {
  const PosPrintingSettingsScreen({super.key});
  @override
  State<PosPrintingSettingsScreen> createState() => _PosPrintingSettingsScreenState();
}

class _PosPrintingSettingsScreenState extends State<PosPrintingSettingsScreen> {
  final _service = PosPrintingService();
  final _terminalName = TextEditingController(text: 'MAWA ERP Terminal');
  final _location = TextEditingController();
  PosTerminal? _terminal;
  List<PosPrintAgent> _agents = const [];
  String? _agentId;
  String? _printerId;
  int _paperWidthChars = 42;
  bool _supportsCut = true;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _terminalName.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final terminal = await _service.ensureTerminal();
      final agents = await _service.getAgents();
      if (!mounted) return;
      setState(() {
        _terminal = terminal;
        _agents = agents;
        _terminalName.text = terminal.displayName;
        _location.text = terminal.location;
        _agentId = terminal.agentId;
        _printerId = terminal.defaultReceiptPrinterId;
        for (final agent in agents) {
          for (final printer in agent.printers) {
            if (printer.id == terminal.defaultReceiptPrinterId) {
              _paperWidthChars = printer.paperWidthChars;
              _supportsCut = printer.supportsCut;
            }
          }
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PosPrinter> get _printers => _agents
      .where((a) => a.id == _agentId)
      .expand((a) => a.printers)
      .toList();

  PosPrinter? get _selectedPrinter {
    for (final printer in _printers) {
      if (printer.id == _printerId) return printer;
    }
    return null;
  }

  bool get _selectedPrinterOnline => _selectedPrinter?.online == true;

  void _selectPrinter(String? value) {
    setState(() {
      _printerId = value;
      if (value == null) return;
      for (final printer in _printers) {
        if (printer.id == value) {
          _paperWidthChars = printer.paperWidthChars;
          _supportsCut = printer.supportsCut;
          break;
        }
      }
    });
  }

  Future<void> _save() async {
    setState(() { _loading = true; _error = null; });
    try {
      var terminal = await _service.ensureTerminal(displayName: _terminalName.text, location: _location.text);
      if (_agentId == null) throw AppException('Select a Windows print agent.');
      terminal = await _service.assignTerminal(terminalId: terminal.id, agentId: _agentId!);
      if (!mounted) return;
      setState(() => _terminal = terminal);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('POS print agent saved')));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _testPrint() async {
    if (_agentId == null) { setState(() => _error = 'Select a Windows print agent.'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      var terminal = await _service.ensureTerminal(displayName: _terminalName.text, location: _location.text);
      terminal = await _service.assignTerminal(terminalId: terminal.id, agentId: _agentId!);
      await _service.queueTestPrint(terminalId: terminal.id);
      if (!mounted) return;
      setState(() => _terminal = terminal);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Test print queued to the agent's local receipt printer.")));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createEnrollment() async {
    final name = TextEditingController();
    final location = TextEditingController(text: _location.text);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create print agent setup code'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Agent name', hintText: 'Front Desk PC')),
          const SizedBox(height: 12),
          TextField(controller: location, decoration: const InputDecoration(labelText: 'Location')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create code'))],
      ),
    );
    if (result != true) return;
    if (name.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a name for the Windows print agent.')),
        );
      }
      return;
    }
    try {
      final code = await _service.createEnrollment(agentName: name.text.trim(), location: location.text.trim());
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Agent enrollment code'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Enter this one-time code during Windows agent installation.'),
            const SizedBox(height: 16),
            SelectableText(code.code, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 4)),
            const SizedBox(height: 12),
            Text('Expires: ${code.expiresAt}'),
          ]),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('$e')), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('POS Printing'), actions: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PosPrintJobMonitorScreen())),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Print jobs'),
        ),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: TextStyle(color: Colors.red.shade800)))),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('This ERP terminal', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        TextField(controller: _terminalName, decoration: const InputDecoration(labelText: 'Terminal name')),
                        const SizedBox(height: 12),
                        TextField(controller: _location, decoration: const InputDecoration(labelText: 'Location')),
                        const SizedBox(height: 12),
                        Text('Terminal ID: ${_terminal?.id ?? '-'}', style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Expanded(child: Text('Windows print agent', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))), OutlinedButton.icon(onPressed: _createEnrollment, icon: const Icon(Icons.add_link), label: const Text('Setup code'))]),
                        const SizedBox(height: 12),
                        SearchableDropdownFormField<String>(
                          value: _agents.any((a) => a.id == _agentId) ? _agentId : null,
                          decoration: const InputDecoration(labelText: 'Agent'),
                          items: _agents.where((a) => a.active).map((a) => DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.name}${a.machineName.isEmpty ? '' : ' • ${a.machineName}'}${a.online ? '' : ' • Offline'}'),
                          )).toList(),
                          onChanged: (value) => setState(() {
                            _agentId = value;
                            _printerId = null;
                            _paperWidthChars = 42;
                            _supportsCut = true;
                          }),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'The physical receipt printer is configured locally on the Windows print agent. MAWA ERP only assigns this terminal to an agent.',
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _agentId != null ? _testPrint : null,
                              icon: const Icon(Icons.print_outlined),
                              label: const Text('Test print'),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: _save,
                              icon: const Icon(Icons.save),
                              label: const Text('Save configuration'),
                            ),
                          ],
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Registered agents', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (_agents.isEmpty) const Text('No print agents have enrolled yet.'),
                        ..._agents.map((a) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                a.online ? Icons.computer : Icons.computer_outlined,
                                color: a.online ? Colors.green : Colors.orange,
                              ),
                              title: Text(a.name),
                              subtitle: Text('${a.machineName} • ${a.location}\n${a.online ? 'Online' : 'Offline'} • ${a.printers.length} printer(s) • ${a.lastHeartbeatAt ?? 'Never online'}'),
                              isThreeLine: true,
                            )),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
