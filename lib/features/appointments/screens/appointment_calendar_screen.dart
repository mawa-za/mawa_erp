import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/product_lookup.dart';
import '../../../core/services/product_lookup_service.dart';
import '../../../core/widgets/partner_search_dropdown.dart';
import '../../partners/models/partner.dart';
import '../models/appointment_booking.dart';
import '../services/appointment_booking_service.dart';
import '../../service_orders/services/service_order_service.dart';
import '../../service_orders/screens/service_order_screen.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';

class AppointmentCalendarScreen extends StatefulWidget {
  const AppointmentCalendarScreen({super.key});

  @override
  State<AppointmentCalendarScreen> createState() => _AppointmentCalendarScreenState();
}

class _AppointmentCalendarScreenState extends State<AppointmentCalendarScreen> {
  final AppointmentBookingService _service = AppointmentBookingService();
  final ServiceOrderService _serviceOrderService =
      ServiceOrderService();
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  String _statusFilter = 'ALL';
  bool _isLoading = true;
  String? _error;
  List<AppointmentBooking> _appointments = [];

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final monthStart = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
      final monthEnd = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
      final appointments = await _service.getAppointments(
        fromDate: monthStart,
        toDate: monthEnd,
        status: _statusFilter == 'ALL' ? null : _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _appointments = appointments;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  List<AppointmentBooking> get _selectedDayAppointments {
    return _appointments.where((appointment) => _isSameDay(appointment.date, _selectedDate)).toList();
  }

  int _countForDay(DateTime day) {
    return _appointments.where((appointment) => _isSameDay(appointment.date, day)).length;
  }

  bool _isSameDay(DateTime? left, DateTime right) {
    return left != null && left.year == right.year && left.month == right.month && left.day == right.day;
  }

  Future<void> _openCreateDialog({DateTime? initialDate, AppointmentBooking? appointment}) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppointmentBookingDialog(
        initialDate: initialDate ?? _selectedDate,
        appointment: appointment,
      ),
    );
    if (changed == true) {
      await _loadAppointments();
    }
  }

  Future<void> _updateStatus(AppointmentBooking appointment, String status) async {
    try {
      await _service.updateAppointmentStatus(id: appointment.id, status: status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Appointment marked as ${_statusLabel(status)}')),
      );
      await _loadAppointments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage('Failed to update appointment: $e')), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _cancelAppointment(AppointmentBooking appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel appointment'),
        content: Text('Cancel appointment ${appointment.number.isEmpty ? appointment.id : appointment.number}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel Appointment')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.cancelAppointment(appointment.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment cancelled')));
      await _loadAppointments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage('Failed to cancel appointment: $e')), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openServiceOrder(AppointmentBooking appointment) async {
    try {
      final serviceOrder =
          await _serviceOrderService.createFromAppointment(appointment.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ServiceOrderScreen(
            serviceOrderId: serviceOrder.id,
          ),
        ),
      );
      if (!mounted) return;
      await _loadAppointments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage('Failed to open service order: $e'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Appointments & Calendar'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.calendar_month_outlined), text: 'Calendar'),
              Tab(icon: Icon(Icons.list_alt_outlined), text: 'Appointments'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loadAppointments,
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openCreateDialog(initialDate: _selectedDate),
          icon: const Icon(Icons.add),
          label: const Text('Book Appointment'),
        ),
        body: Column(
          children: [
            _buildSummaryBar(colorScheme),
            if (_error != null)
              MaterialBanner(
                content: Text(_error!),
                leading: const Icon(Icons.error_outline),
                backgroundColor: colorScheme.errorContainer,
                actions: [
                  TextButton(onPressed: _loadAppointments, child: const Text('Retry')),
                ],
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _buildCalendarTab(colorScheme),
                        _buildListTab(colorScheme),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar(ColorScheme colorScheme) {
    final booked = _appointments.where((a) => a.status.toUpperCase() == 'BOOKED').length;
    final processed = _appointments.where((a) => a.status.toUpperCase() == 'PROCESSED').length;
    final cancelled = _appointments.where((a) => a.status.toUpperCase() == 'CANCELLED').length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 8))],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _metricChip('Total', _appointments.length, Icons.event_available_outlined, colorScheme.primary),
          _metricChip('Booked', booked, Icons.pending_actions_outlined, Colors.blue),
          _metricChip('Processed', processed, Icons.check_circle_outline, Colors.green),
          _metricChip('Cancelled', cancelled, Icons.cancel_outlined, Colors.redAccent),
          const SizedBox(width: 12),
          SizedBox(
            width: 220,
            child: SearchableDropdownFormField<String>(
              value: _statusFilter,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
                DropdownMenuItem(value: 'BOOKED', child: Text('Booked')),
                DropdownMenuItem(value: 'PROCESSED', child: Text('Processed')),
                DropdownMenuItem(value: 'MISSED', child: Text('Missed')),
                DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
              ],
              onChanged: (value) async {
                if (value == null) return;
                setState(() => _statusFilter = value);
                await _loadAppointments();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
          Text('$value', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCalendarTab(ColorScheme colorScheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wide = constraints.maxWidth >= 980;
        final calendar = _buildMonthCalendar(colorScheme);
        final agenda = _buildDayAgenda(colorScheme);
        if (wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: calendar),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: agenda),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          children: [calendar, const SizedBox(height: 16), agenda],
        );
      },
    );
  }

  Widget _buildMonthCalendar(ColorScheme colorScheme) {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final int leadingEmptyDays = firstDay.weekday % 7;
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final totalCells = ((leadingEmptyDays + daysInMonth) / 7).ceil() * 7;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () async {
                    setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1));
                    await _loadAppointments();
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_focusedMonth),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1));
                    await _loadAppointments();
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.8,
              children: const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                  .map((d) => Center(child: Text(d, style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey))))
                  .toList(),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: totalCells,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1.35),
              itemBuilder: (context, index) {
                final dayNumber = index - leadingEmptyDays + 1;
                if (dayNumber < 1 || dayNumber > daysInMonth) return const SizedBox.shrink();
                final day = DateTime(_focusedMonth.year, _focusedMonth.month, dayNumber);
                final selected = _isSameDay(day, _selectedDate);
                final today = _isSameDay(day, DateTime.now());
                final count = _countForDay(day);
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _selectedDate = day),
                  onDoubleTap: () => _openCreateDialog(initialDate: day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.all(4),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: selected ? colorScheme.primary : today ? colorScheme.primary.withOpacity(0.08) : Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: selected ? colorScheme.primary : today ? colorScheme.primary : Colors.transparent),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        if (count > 0)
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: selected ? colorScheme.onPrimary : colorScheme.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: selected ? colorScheme.primary : colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayAgenda(ColorScheme colorScheme) {
    final appointments = _selectedDayAppointments;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Book on this date',
                  onPressed: () => _openCreateDialog(initialDate: _selectedDate),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const Divider(height: 24),
            if (appointments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_busy_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('No appointments for this day', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              )
            else
              ...appointments.map((appointment) => _buildAppointmentTile(appointment, colorScheme)),
          ],
        ),
      ),
    );
  }

  Widget _buildListTab(ColorScheme colorScheme) {
    if (_appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_outlined, size: 72, color: Colors.grey[350]),
            const SizedBox(height: 12),
            const Text('No appointments found'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openCreateDialog(initialDate: _selectedDate),
              icon: const Icon(Icons.add),
              label: const Text('Book Appointment'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: _appointments.length,
      itemBuilder: (context, index) => _buildAppointmentTile(_appointments[index], colorScheme),
    );
  }

  Widget _buildAppointmentTile(AppointmentBooking appointment, ColorScheme colorScheme) {
    final statusColor = _statusColor(appointment.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.12),
          child: Icon(Icons.event_note_outlined, color: statusColor),
        ),
        title: Text(
          appointment.customerName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${appointment.dateLabel} at ${appointment.timeLabel} • ${appointment.serviceName}'),
              const SizedBox(height: 2),
              Text('Employee: ${appointment.employeeName}'),
              if (appointment.duration.isNotEmpty) Text('Duration: ${appointment.duration}'),
            ],
          ),
        ),
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Chip(
              label: Text(_statusLabel(appointment.status)),
              visualDensity: VisualDensity.compact,
              backgroundColor: statusColor.withOpacity(0.1),
              labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
              side: BorderSide(color: statusColor.withOpacity(0.2)),
            ),
            PopupMenuButton<String>(
              tooltip: 'Actions',
              onSelected: (value) {
                if (value == 'edit') _openCreateDialog(appointment: appointment, initialDate: appointment.date);
                if (value == 'processed') _updateStatus(appointment, 'PROCESSED');
                if (value == 'missed') _updateStatus(appointment, 'MISSED');
                if (value == 'booked') _updateStatus(appointment, 'BOOKED');
                if (value == 'service-order') {
                  _openServiceOrder(appointment);
                }
                if (value == 'cancel') _cancelAppointment(appointment);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit / Reschedule'))),
                if (!appointment.isCancelled &&
                    appointment.status.toUpperCase() != 'MISSED')
                  const PopupMenuItem(
                    value: 'service-order',
                    child: ListTile(
                      leading: Icon(Icons.assignment_outlined),
                      title: Text('Create / Open Service Order'),
                    ),
                  ),
                if (!appointment.isProcessed)
                  const PopupMenuItem(value: 'processed', child: ListTile(leading: Icon(Icons.check_circle_outline), title: Text('Mark Processed'))),
                const PopupMenuItem(value: 'missed', child: ListTile(leading: Icon(Icons.person_off_outlined), title: Text('Mark Missed'))),
                if (!appointment.isBooked)
                  const PopupMenuItem(value: 'booked', child: ListTile(leading: Icon(Icons.pending_actions_outlined), title: Text('Reopen as Booked'))),
                if (!appointment.isCancelled)
                  const PopupMenuItem(value: 'cancel', child: ListTile(leading: Icon(Icons.cancel_outlined), title: Text('Cancel'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PROCESSED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.redAccent;
      case 'MISSED':
        return Colors.orange;
      case 'BOOKED':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    return status.replaceAll('-', ' ').replaceAll('_', ' ').toLowerCase().split(' ').map((part) {
      if (part.isEmpty) return part;
      return '${part[0].toUpperCase()}${part.substring(1)}';
    }).join(' ');
  }
}

class AppointmentBookingDialog extends StatefulWidget {
  final DateTime initialDate;
  final AppointmentBooking? appointment;

  const AppointmentBookingDialog({
    super.key,
    required this.initialDate,
    this.appointment,
  });

  @override
  State<AppointmentBookingDialog> createState() => _AppointmentBookingDialogState();
}

class _AppointmentBookingDialogState extends State<AppointmentBookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final AppointmentBookingService _service = AppointmentBookingService();
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  Partner? _customer;
  Partner? _employee;
  String? _productId;
  bool _isSaving = false;
  late final Future<List<ProductLookup>> _productsFuture;

  bool get _isEditing => widget.appointment != null;

  @override
  void initState() {
    super.initState();
    final appointment = widget.appointment;
    _selectedDate = appointment?.date ?? widget.initialDate;
    _selectedTime = _parseTimeOfDay(appointment?.time) ?? TimeOfDay.now();
    _customer = appointment?.customer;
    _employee = appointment?.employeeResponsible;
    _productId = appointment?.productId;
    _productsFuture = ProductLookupService().getProducts(type: 'SERVICE');
  }

  TimeOfDay? _parseTimeOfDay(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _timeValue(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customer == null && !_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a customer')));
      return;
    }
    if (_employee == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an employee')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        await _service.updateAppointment(
          id: widget.appointment!.id,
          date: _selectedDate,
          time: _timeValue(_selectedTime),
          employeeId: _employee!.id,
        );
      } else {
        await _service.createAppointment(
          customerId: _customer!.id,
          employeeId: _employee!.id,
          date: _selectedDate,
          time: _timeValue(_selectedTime),
          productId: _productId,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage('Failed to save appointment: $e')), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(Icons.event_available_outlined, color: colorScheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isEditing ? 'Edit Appointment' : 'Book Appointment',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(onPressed: _isSaving ? null : () => Navigator.pop(context, false), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (!_isEditing) ...[
                    PartnerSearchDropdown(
                      role: 'CUSTOMER',
                      label: 'Search customer',
                      onPartnerSelected: (partner) => _customer = partner,
                      validator: (_) => _customer == null ? 'Customer is required' : null,
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    _readOnlyInfo('Customer', widget.appointment!.customerName, Icons.person_outline),
                    const SizedBox(height: 16),
                  ],
                  PartnerSearchDropdown(
                    role: 'EMPLOYEE',
                    label: _employee?.fullName ?? 'Search employee responsible',
                    initialPartnerId: _employee?.id,
                    onPartnerSelected: (partner) => _employee = partner,
                    validator: (_) => _employee == null ? 'Employee responsible is required' : null,
                  ),
                  const SizedBox(height: 16),
                  if (!_isEditing) FutureBuilder<List<ProductLookup>>(
                    future: _productsFuture,
                    builder: (context, snapshot) {
                      final products = snapshot.data ?? const <ProductLookup>[];
                      return SearchableDropdownFormField<String>(
                        value: products.any((p) => p.id == _productId) ? _productId : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Service / product',
                          prefixIcon: Icon(Icons.miscellaneous_services_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(value: '', child: Text('No service selected')),
                          ...products.map((product) => DropdownMenuItem<String>(
                                value: product.id,
                                child: Text(product.description.isEmpty ? product.code : '${product.code} - ${product.description}'),
                              )),
                        ],
                        onChanged: snapshot.connectionState == ConnectionState.waiting
                            ? null
                            : (value) => setState(() => _productId = value == null || value.isEmpty ? null : value),
                      );
                    },
                  ) else _readOnlyInfo('Service', widget.appointment!.serviceName, Icons.miscellaneous_services_outlined),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _selectionTile(
                          label: 'Date',
                          value: DateFormat('yyyy-MM-dd').format(_selectedDate),
                          icon: Icons.calendar_today_outlined,
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _selectionTile(
                          label: 'Time',
                          value: _timeValue(_selectedTime),
                          icon: Icons.access_time_outlined,
                          onTap: _pickTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: Text(_isEditing ? 'Save Changes' : 'Create Appointment'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _readOnlyInfo(String label, String value, IconData icon) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()),
      child: Text(value.isEmpty ? '-' : value),
    );
  }

  Widget _selectionTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()),
        child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
