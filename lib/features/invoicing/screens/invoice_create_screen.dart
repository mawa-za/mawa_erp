import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import '../../../core/api_client.dart';
import '../../../core/widgets/quick_customer_create_dialog.dart';
import '../../partners/models/partner.dart';
import '../models/invoice_detail.dart';
import '../services/invoice_service.dart';
import 'invoice_detail_screen.dart';

class InvoiceItemDraft {
  final TextEditingController productController;
  final TextEditingController descriptionController;
  final TextEditingController amountController;
  final TextEditingController quantityController;
  final TextEditingController discountController;
  String? productId;
  bool applyVat;

  InvoiceItemDraft({
    String product = '',
    String description = '',
    String amount = '',
    String quantity = '1',
    String discount = '0',
    this.productId,
    this.applyVat = true,
  })  : productController = TextEditingController(text: product),
        descriptionController = TextEditingController(text: description),
        amountController = TextEditingController(text: amount),
        quantityController = TextEditingController(text: quantity),
        discountController = TextEditingController(text: discount);

  void dispose() {
    productController.dispose();
    descriptionController.dispose();
    amountController.dispose();
    quantityController.dispose();
    discountController.dispose();
  }
}

class Product {
  final String id;
  final String code;
  final String description;
  final double price;

  const Product({
    required this.id,
    required this.code,
    required this.description,
    required this.price,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    double price = 0;
    final pricings = json['pricings'];
    if (pricings is List && pricings.isNotEmpty) {
      final value = pricings.first is Map ? pricings.first['value'] : null;
      price = value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '') ?? 0;
    }

    return Product(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      description:
          json['name']?.toString() ?? json['description']?.toString() ?? '',
      price: price,
    );
  }
}

class InvoiceCreateScreen extends StatefulWidget {
  final InvoiceDetail? existingInvoice;

  const InvoiceCreateScreen({super.key, this.existingInvoice});

  @override
  State<InvoiceCreateScreen> createState() => _InvoiceCreateScreenState();
}

class _InvoiceCreateScreenState extends State<InvoiceCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final List<InvoiceItemDraft> _items = [];

  bool _isSubmitting = false;
  bool _isLoadingProducts = true;
  String? _productLoadError;
  Partner? _selectedPartner;
  DateTime _invoiceDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  List<Product> _availableProducts = [];

  final double _vatRate = 15;
  bool _isVatInclusive = true;

  bool get _isEditing => widget.existingInvoice != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadExistingInvoice();
    } else {
      _items.add(InvoiceItemDraft());
    }
    _fetchProducts();
  }

  void _loadExistingInvoice() {
    final invoice = widget.existingInvoice!;
    _invoiceDate = invoice.invoiceDate;
    _dueDate = invoice.dueDate ?? DateTime.now().add(const Duration(days: 30));
    _referenceController.text = invoice.reference;

    if (invoice.customerId != null && invoice.customerId!.isNotEmpty) {
      _fetchPartnerDetails(invoice.customerId!);
    }

    for (final item in invoice.items) {
      final grossAmount = item.quantity * item.unitPrice;
      final derivedDiscountPercentage = item.discountPercentage > 0
          ? item.discountPercentage
          : grossAmount > 0
              ? (item.discountCents / 100) / grossAmount * 100
              : 0.0;
      _items.add(
        InvoiceItemDraft(
          product: item.productCode,
          description: item.productName,
          amount: item.unitPrice.toStringAsFixed(2),
          quantity: _formatQuantity(item.quantity),
          discount: derivedDiscountPercentage.toStringAsFixed(2),
          productId: item.productId,
          applyVat: item.taxCents > 0,
        ),
      );
    }

    if (_items.isEmpty) {
      _items.add(InvoiceItemDraft());
    }
  }

  String _formatQuantity(double quantity) {
    return quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(2);
  }

  Future<void> _fetchPartnerDetails(String partnerId) async {
    try {
      final response = await ApiClient().get('/v2/partner/$partnerId');
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() => _selectedPartner = Partner.fromJson(data));
      }
    } catch (e) {
      debugPrint('Error fetching partner details for invoice: $e');
    }
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _productLoadError = null;
    });

    try {
      final response =
          await ApiClient().get('/product?availableForSale=true');
      if (response.statusCode != 200) {
        throw Exception(
          friendlyErrorMessage(
            response.body,
            statusCode: response.statusCode,
            fallback: 'Products could not be loaded.',
          ),
        );
      }

      final data = jsonDecode(response.body) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _availableProducts = data
            .whereType<Map<String, dynamic>>()
            .map(Product.fromJson)
            .toList()
          ..sort((a, b) => a.description.compareTo(b.description));
        _isLoadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProducts = false;
        _productLoadError = friendlyErrorMessage(
          e,
          fallback:
              'Products could not be loaded. You can still enter invoice lines manually.',
        );
      });
    }
  }

  Future<List<Partner>> _searchPartners(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final response = await ApiClient().get(
        '/v2/partner',
        queryParameters: {
          'query': query.trim(),
          'role': 'CUSTOMER',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data
            .whereType<Map<String, dynamic>>()
            .map(Partner.fromJson)
            .toList();
      }
    } catch (e) {
      debugPrint('Error searching customers: $e');
    }
    return [];
  }

  Future<void> _createCustomerFromSearch(
    SearchController controller,
    String searchedValue,
  ) async {
    controller.closeView(searchedValue);
    final created = await showQuickCustomerCreateDialog(context);
    if (created != null && mounted) {
      setState(() => _selectedPartner = created);
    }
  }

  void _addItem() {
    setState(() => _items.add(InvoiceItemDraft()));
  }

  void _removeItem(int index) {
    if (_items.length == 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Map<String, double> _calculateLineValues(InvoiceItemDraft item) {
    final quantity = double.tryParse(item.quantityController.text) ?? 0;
    final unitPrice = double.tryParse(item.amountController.text) ?? 0;
    final discountPercentage =
        double.tryParse(item.discountController.text) ?? 0;
    final grossAmount = quantity * unitPrice;
    final discountAmount = grossAmount * (discountPercentage / 100);
    final netAmount = grossAmount - discountAmount;

    double subtotal = netAmount;
    double vatAmount = 0;
    double total = netAmount;

    if (item.applyVat) {
      if (_isVatInclusive) {
        total = netAmount;
        subtotal = total / (1 + (_vatRate / 100));
        vatAmount = total - subtotal;
      } else {
        subtotal = netAmount;
        vatAmount = subtotal * (_vatRate / 100);
        total = subtotal + vatAmount;
      }
    }

    return {
      'subtotal': subtotal,
      'vatAmount': vatAmount,
      'total': total,
      'discountAmount': discountAmount,
    };
  }

  Map<String, double> _calculateTotals() {
    double subtotal = 0;
    double vatAmount = 0;
    double total = 0;
    double discountAmount = 0;

    for (final item in _items) {
      if (!_isLinePopulated(item)) continue;
      final values = _calculateLineValues(item);
      subtotal += values['subtotal']!;
      vatAmount += values['vatAmount']!;
      total += values['total']!;
      discountAmount += values['discountAmount']!;
    }

    return {
      'subtotal': subtotal,
      'vatAmount': vatAmount,
      'total': total,
      'discountAmount': discountAmount,
    };
  }

  bool _isLinePopulated(InvoiceItemDraft item) {
    final price = double.tryParse(item.amountController.text) ?? 0;
    return item.productId != null ||
        item.productController.text.trim().isNotEmpty ||
        item.descriptionController.text.trim().isNotEmpty ||
        price > 0;
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPartner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final filledItems = _items.where(_isLinePopulated).toList();
    if (filledItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one invoice item.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final totals = _calculateTotals();
      final linesPayload = filledItems.map((item) {
        final quantity = double.parse(item.quantityController.text);
        final unitPrice = double.parse(item.amountController.text);
        final values = _calculateLineValues(item);

        return {
          'productId': item.productId,
          'description': item.descriptionController.text.trim(),
          'quantity': quantity,
          'unitPriceCents': (unitPrice * 100).round(),
          'discountCents': (values['discountAmount']! * 100).round(),
          'taxCents': (values['vatAmount']! * 100).round(),
          'subtotalCents': (values['subtotal']! * 100).round(),
          'totalCents': (values['total']! * 100).round(),
          'showAmount': true,
        };
      }).toList();

      final payload = {
        'id': widget.existingInvoice?.id,
        'partnerId': _selectedPartner!.id,
        'invoiceDate': DateFormat('yyyy-MM-dd').format(_invoiceDate),
        'dueDate': DateFormat('yyyy-MM-dd').format(_dueDate),
        'externalRef': _referenceController.text.trim(),
        'subtotalCents': (totals['subtotal']! * 100).round(),
        'taxCents': (totals['vatAmount']! * 100).round(),
        'discountCents': (totals['discountAmount']! * 100).round(),
        'totalCents': (totals['total']! * 100).round(),
        'currency': 'ZAR',
        'lines': linesPayload,
        'status': widget.existingInvoice?.status ?? 'DRAFT',
      };

      final responseData = !_isEditing
          ? await InvoiceService().createInvoice(payload)
          : await InvoiceService().updateInvoice(
              widget.existingInvoice!.id,
              payload,
            );
      final savedId = responseData['id']?.toString();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Invoice updated successfully.'
                : 'Invoice created successfully.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (!_isEditing && savedId != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => InvoiceDetailScreen(invoiceId: savedId),
          ),
        );
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyErrorMessage(
                e,
                fallback: 'The invoice could not be saved. Please try again.',
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 640;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Invoice' : 'Create Invoice'),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          if (compact)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton.filled(
                tooltip: _isEditing ? 'Save changes' : 'Create invoice',
                onPressed: _isSubmitting ? null : _saveInvoice,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 19),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _saveInvoice,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(_isEditing ? 'Save Changes' : 'Create Invoice'),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 1200
                ? 32.0
                : constraints.maxWidth >= 700
                    ? 24.0
                    : 16.0;

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      24,
                      horizontalPadding,
                      36,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1440),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildDocumentOverviewCard(colorScheme),
                            const SizedBox(height: 24),
                            _buildSectionCard(
                              icon: Icons.person_outline_rounded,
                              title: 'Customer',
                              subtitle:
                                  'Select the customer who will receive this invoice.',
                              child: _buildCustomerSection(colorScheme),
                            ),
                            const SizedBox(height: 20),
                            _buildSectionCard(
                              icon: Icons.description_outlined,
                              title: 'Invoice details',
                              subtitle:
                                  'Capture the document reference, dates and VAT pricing method.',
                              child: _buildGeneralDetails(colorScheme),
                            ),
                            const SizedBox(height: 20),
                            _buildItemsSection(colorScheme),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _buildBottomSummary(colorScheme),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDocumentOverviewCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withOpacity(0.75),
            colorScheme.primaryContainer.withOpacity(0.28),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              color: colorScheme.onPrimary,
              size: 26,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing
                      ? 'Update ${widget.existingInvoice!.number}'
                      : 'New customer invoice',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Complete the customer and document details, then add the products or services being invoiced.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (_isEditing)
            _buildStatusPill(widget.existingInvoice!.status, colorScheme),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        status.replaceAll('_', ' ').replaceAll('-', ' '),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildCustomerSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCustomerSearch(),
        if (_selectedPartner != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorScheme.primary.withOpacity(0.14)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  child: const Icon(Icons.person_outline_rounded, size: 22),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedPartner!.fullName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (_selectedPartner!.number.isNotEmpty)
                            'Customer ${_selectedPartner!.number}',
                          if (_selectedPartner!.identityNumber.isNotEmpty)
                            'ID ${_selectedPartner!.identityNumber}',
                        ].join('  •  '),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Change customer',
                  onPressed: () => setState(() => _selectedPartner = null),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCustomerSearch() {
    final colorScheme = Theme.of(context).colorScheme;
    return SearchAnchor(
      isFullScreen: false,
      viewConstraints: const BoxConstraints(maxHeight: 420),
      viewHintText: 'Search by name, contact number or email',
      builder: (context, controller) {
        return SearchBar(
          controller: controller,
          onTap: controller.openView,
          onChanged: (_) => controller.openView(),
          leading: Icon(Icons.search_rounded, color: colorScheme.primary),
          hintText: 'Search customer by name, mobile or email',
          elevation: const WidgetStatePropertyAll(0),
          side: WidgetStatePropertyAll(
            BorderSide(color: colorScheme.outlineVariant),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          backgroundColor: WidgetStatePropertyAll(colorScheme.surface),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14),
          ),
        );
      },
      suggestionsBuilder: (context, controller) async {
        final query = controller.text.trim();
        if (query.length < 2) {
          return const [
            ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Enter at least two characters to search.'),
            ),
          ];
        }

        final partners = await _searchPartners(query);
        final suggestions = <Widget>[];
        if (partners.isEmpty) {
          suggestions.add(
            const ListTile(
              leading: Icon(Icons.search_off_rounded),
              title: Text('No matching customers found.'),
              subtitle: Text('You can create a customer after completing this search.'),
            ),
          );
        } else {
          suggestions.addAll(partners.map((partner) {
          return ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person_outline_rounded),
            ),
            title: Text(
              partner.fullName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              partner.number.isEmpty
                  ? partner.identityNumber
                  : 'Customer ${partner.number}',
            ),
            onTap: () {
              setState(() => _selectedPartner = partner);
              controller.closeView(partner.fullName);
            },
          );
          }));
        }

        suggestions.add(
          ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person_add_alt_1_rounded),
            ),
            title: const Text(
              'Quick Create Customer',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Names plus contact number and/or email'),
            onTap: () => _createCustomerFromSearch(controller, query),
          ),
        );
        return suggestions;
      },
    );
  }

  Widget _buildGeneralDetails(ColorScheme colorScheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final reference = _buildReferenceField();
        final invoiceDate = _buildDatePickerField(
          'Invoice date',
          _invoiceDate,
          (date) => setState(() => _invoiceDate = date),
        );
        final dueDate = _buildDatePickerField(
          'Due date',
          _dueDate,
          (date) => setState(() => _dueDate = date),
        );

        return Column(
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: reference),
                  const SizedBox(width: 14),
                  Expanded(child: invoiceDate),
                  const SizedBox(width: 14),
                  Expanded(child: dueDate),
                ],
              )
            else ...[
              reference,
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: invoiceDate),
                  const SizedBox(width: 12),
                  Expanded(child: dueDate),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.secondary.withOpacity(0.12),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, vatConstraints) {
                  final compactVat = vatConstraints.maxWidth < 620;
                  final description = Row(
                    children: [
                      Icon(
                        Icons.percent_rounded,
                        size: 20,
                        color: colorScheme.secondary,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VAT pricing',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Choose whether entered unit prices include VAT.',
                              style: TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final selector = SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Exclusive')),
                      ButtonSegment(value: true, label: Text('Inclusive')),
                    ],
                    selected: {_isVatInclusive},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      setState(() => _isVatInclusive = selection.first);
                    },
                  );

                  if (compactVat) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        description,
                        const SizedBox(height: 12),
                        selector,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: description),
                      const SizedBox(width: 16),
                      selector,
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReferenceField() {
    return TextFormField(
      controller: _referenceController,
      decoration: _inputDecoration(
        label: 'Reference',
        hint: 'Customer PO, case or internal reference',
        icon: Icons.tag_rounded,
      ),
    );
  }

  Widget _buildDatePickerField(
    String label,
    DateTime date,
    ValueChanged<DateTime> onPicked,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: _inputDecoration(
          label: label,
          icon: Icons.calendar_month_outlined,
        ),
        child: Text(
          DateFormat('dd MMM yyyy').format(date),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildItemsSection(ColorScheme colorScheme) {
    return _buildSectionCard(
      icon: Icons.list_alt_rounded,
      title: 'Invoice items',
      subtitle:
          'Select a product or service, then confirm the description, quantity and pricing.',
      trailing: FilledButton.tonalIcon(
        onPressed: _addItem,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Add item'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_productLoadError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withOpacity(0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colorScheme.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _productLoadError!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _fetchProducts,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ...List.generate(
            _items.length,
            (index) => Padding(
              padding: EdgeInsets.only(bottom: index == _items.length - 1 ? 0 : 14),
              child: _buildItemCard(index, colorScheme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(int index, ColorScheme colorScheme) {
    final item = _items[index];
    final values = _calculateLineValues(item);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.85)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 920;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Line item',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: _items.length == 1
                        ? 'At least one item is required'
                        : 'Remove item',
                    onPressed:
                        _items.length == 1 ? null : () => _removeItem(index),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: _buildProductSearch(item)),
                    const SizedBox(width: 12),
                    Expanded(flex: 5, child: _buildDescriptionField(item)),
                    const SizedBox(width: 12),
                    SizedBox(width: 100, child: _buildQuantityField(item)),
                    const SizedBox(width: 12),
                    SizedBox(width: 145, child: _buildUnitPriceField(item)),
                    const SizedBox(width: 12),
                    SizedBox(width: 110, child: _buildDiscountField(item)),
                  ],
                )
              else ...[
                _buildProductSearch(item),
                const SizedBox(height: 12),
                _buildDescriptionField(item),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildQuantityField(item)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildUnitPriceField(item)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDiscountField(item),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withOpacity(0.7),
                  ),
                ),
                child: Wrap(
                  spacing: 18,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox.adaptive(
                          value: item.applyVat,
                          onChanged: (value) {
                            setState(() => item.applyVat = value ?? true);
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                        const Text(
                          'VAT applies',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        _buildLineMetric(
                          'Subtotal',
                          values['subtotal']!,
                        ),
                        _buildLineMetric('VAT', values['vatAmount']!),
                        _buildLineMetric(
                          'Line total',
                          values['total']!,
                          emphasised: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductSearch(InvoiceItemDraft item) {
    final colorScheme = Theme.of(context).colorScheme;
    return SearchAnchor(
      isFullScreen: false,
      viewConstraints: const BoxConstraints(maxHeight: 420),
      viewHintText: 'Search products and services',
      builder: (context, controller) {
        final selectedLabel = item.productController.text.trim();
        return SearchBar(
          controller: controller,
          onTap: controller.openView,
          onChanged: (_) => controller.openView(),
          leading: _isLoadingProducts
              ? const Padding(
                  padding: EdgeInsets.all(13),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Icon(Icons.inventory_2_outlined, color: colorScheme.primary),
          hintText: selectedLabel.isEmpty
              ? 'Product or service (optional)'
              : selectedLabel,
          trailing: selectedLabel.isEmpty
              ? null
              : [
                  IconButton(
                    tooltip: 'Clear product',
                    onPressed: () {
                      controller.clear();
                      setState(() {
                        item.productId = null;
                        item.productController.clear();
                      });
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
          elevation: const WidgetStatePropertyAll(0),
          side: WidgetStatePropertyAll(
            BorderSide(color: colorScheme.outlineVariant),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          backgroundColor: WidgetStatePropertyAll(colorScheme.surface),
          constraints: const BoxConstraints(minHeight: 52),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12),
          ),
        );
      },
      suggestionsBuilder: (context, controller) {
        if (_isLoadingProducts) {
          return const [
            ListTile(
              leading: CircularProgressIndicator(strokeWidth: 2),
              title: Text('Loading products and services...'),
            ),
          ];
        }

        final query = controller.text.trim().toLowerCase();
        final filtered = _availableProducts.where((product) {
          return query.isEmpty ||
              product.code.toLowerCase().contains(query) ||
              product.description.toLowerCase().contains(query);
        }).take(50).toList();

        if (filtered.isEmpty) {
          return const [
            ListTile(
              leading: Icon(Icons.search_off_rounded),
              title: Text('No matching products or services.'),
              subtitle: Text('You may enter a manual line description.'),
            ),
          ];
        }

        return filtered.map((product) {
          return ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.inventory_2_outlined, size: 19),
            ),
            title: Text(
              product.description,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${product.code}  •  R ${product.price.toStringAsFixed(2)}',
            ),
            onTap: () {
              setState(() {
                item.productId = product.id;
                item.productController.text = product.code;
                item.descriptionController.text = product.description;
                item.amountController.text = product.price.toStringAsFixed(2);
              });
              controller.closeView(
                '${product.code} — ${product.description}',
              );
            },
          );
        }).toList();
      },
    );
  }

  Widget _buildDescriptionField(InvoiceItemDraft item) {
    return TextFormField(
      controller: item.descriptionController,
      decoration: _inputDecoration(
        label: 'Description',
        hint: 'What is being invoiced?',
        icon: Icons.notes_rounded,
      ),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        if (!_isLinePopulated(item)) return null;
        if ((value ?? '').trim().isEmpty) {
          return 'Enter a line description';
        }
        return null;
      },
    );
  }

  Widget _buildQuantityField(InvoiceItemDraft item) {
    return TextFormField(
      controller: item.quantityController,
      decoration: _inputDecoration(label: 'Quantity'),
      textAlign: TextAlign.right,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        if (!_isLinePopulated(item)) return null;
        final quantity = double.tryParse((value ?? '').trim());
        if (quantity == null || quantity <= 0) return 'Invalid quantity';
        return null;
      },
    );
  }

  Widget _buildUnitPriceField(InvoiceItemDraft item) {
    return TextFormField(
      controller: item.amountController,
      decoration: _inputDecoration(
        label: _isVatInclusive ? 'Unit price (incl. VAT)' : 'Unit price (excl. VAT)',
        prefix: 'R ',
      ),
      textAlign: TextAlign.right,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        if (!_isLinePopulated(item)) return null;
        final amount = double.tryParse((value ?? '').trim());
        if (amount == null || amount < 0) return 'Invalid amount';
        return null;
      },
    );
  }

  Widget _buildDiscountField(InvoiceItemDraft item) {
    return TextFormField(
      controller: item.discountController,
      decoration: _inputDecoration(label: 'Discount', suffix: '%'),
      textAlign: TextAlign.right,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        if (!_isLinePopulated(item)) return null;
        final discount = double.tryParse((value ?? '').trim());
        if (discount == null || discount < 0 || discount > 100) {
          return 'Use 0–100';
        }
        return null;
      },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    IconData? icon,
    String? prefix,
    String? suffix,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      prefixText: prefix,
      suffixText: suffix,
      filled: true,
      fillColor: colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    );
  }

  Widget _buildLineMetric(
    String label,
    double value, {
    bool emphasised = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'R ${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: emphasised ? 14 : 12,
            fontWeight: emphasised ? FontWeight.w900 : FontWeight.w700,
            color: emphasised ? colorScheme.primary : null,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSummary(ColorScheme colorScheme) {
    final totals = _calculateTotals();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 16,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final summary = Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                _buildSummaryMetric('Subtotal', totals['subtotal']!),
                if (totals['discountAmount']! > 0)
                  _buildSummaryMetric(
                    'Discount',
                    totals['discountAmount']!,
                    negative: true,
                  ),
                _buildSummaryMetric('VAT', totals['vatAmount']!),
                _buildSummaryMetric(
                  'Total',
                  totals['total']!,
                  emphasised: true,
                ),
              ],
            );
            final saveButton = SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _saveInvoice,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 19),
                label: Text(_isEditing ? 'Save changes' : 'Create invoice'),
              ),
            );

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            summary,
                            const SizedBox(height: 12),
                            saveButton,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: summary),
                            const SizedBox(width: 24),
                            saveButton,
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(
    String label,
    double value, {
    bool emphasised = false,
    bool negative = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: emphasised ? 150 : 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${negative ? '- ' : ''}R ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: emphasised ? 19 : 14,
              fontWeight: emphasised ? FontWeight.w900 : FontWeight.w700,
              color: emphasised
                  ? colorScheme.primary
                  : negative
                      ? colorScheme.error
                      : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    _referenceController.dispose();
    super.dispose();
  }
}
