import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';
import '../models/invoice_detail.dart';
import '../../partners/models/partner.dart';
import 'invoice_detail_screen.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class InvoiceItemDraft {
  final TextEditingController productController;
  final TextEditingController descriptionController;
  final TextEditingController amountController;
  final TextEditingController quantityController;
  final TextEditingController discountController;
  String? productId;
  ProductType? selectedType;
  List<Product> availableProducts = [];
  bool isLoadingProducts = false;
  bool applyVat = true;

  InvoiceItemDraft({
    String product = '',
    String description = '',
    String amount = '',
    String quantity = '1',
    String discount = '0',
    this.productId,
    this.selectedType,
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

  Product({
    required this.id,
    required this.code,
    required this.description,
    required this.price,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    double price = 0;
    if (json['pricings'] != null && (json['pricings'] as List).isNotEmpty) {
      price = (json['pricings'][0]['value'] ?? 0).toDouble();
    }
    return Product(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      description: json['name'] ?? json['description'] ?? '',
      price: price,
    );
  }
}

class ProductType {
  final String code;
  final String description;

  ProductType({required this.code, required this.description});

  factory ProductType.fromJson(Map<String, dynamic> json) {
    return ProductType(
      code: json['code'] ?? '',
      description: json['name'] ?? json['description'] ?? '',
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
  bool _isSubmitting = false;
  
  // Selection state
  Partner? _selectedPartner;
  DateTime _invoiceDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  final _referenceController = TextEditingController();
  
  // Product Types Global List
  List<ProductType> _productTypes = [];
  bool _isLoadingTypes = true;
  
  // VAT State
  double _vatRate = 15.0; // Default VAT rate in South Africa
  bool _isVatInclusive = true;
  
  // Global Cache for Category -> Products
  final Map<String, List<Product>> _categoryProductCache = {};
  
  // Dynamic Items
  final List<InvoiceItemDraft> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchProductTypes();
    if (widget.existingInvoice != null) {
      _loadExistingInvoice();
    }
  }

  void _loadExistingInvoice() {
    final inv = widget.existingInvoice!;
    _invoiceDate = inv.invoiceDate;
    _dueDate = inv.dueDate ?? DateTime.now().add(const Duration(days: 30));
    _referenceController.text = inv.reference;
    
    // Fetch full partner details to have complete object for the UI
    if (inv.customerId != null && inv.customerId!.isNotEmpty) {
      _fetchPartnerDetails(inv.customerId!);
    }
    
    // Clear initial empty items if any, then add existing
    _items.clear();
    for (var item in inv.items) {
      _items.add(InvoiceItemDraft(
        product: item.productCode,
        description: item.productName,
        amount: item.unitPrice.toString(),
        quantity: item.quantity.toString(),
        discount: item.discountPercentage.toString(),
        productId: item.productId,
      ));
    }
  }

  Future<void> _fetchPartnerDetails(String partnerId) async {
    try {
      final response = await ApiClient().get('/v2/partner/$partnerId');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          _selectedPartner = Partner.fromJson(data);
        });
      }
    } catch (e) {
      debugPrint('Error fetching partner details for edit: $e');
    }
  }

  Future<void> _fetchProductTypes() async {
    try {
      final response = await ApiClient().get('/v2/product-types');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _productTypes = data.map((json) => ProductType.fromJson(json)).toList();
          _isLoadingTypes = false;
          
          if (widget.existingInvoice == null) {
            // Add 4 default items only if creating new
            for (int i = 0; i < 4; i++) {
              _items.add(InvoiceItemDraft(
                selectedType: _productTypes.isNotEmpty ? _productTypes.first : null,
              ));
            }
          }
        });
        
        // Load products for items
        for (var item in _items) {
          if (item.selectedType != null) {
            _loadProductsForItem(item);
          }
        }
      }
    } catch (e) {
      setState(() => _isLoadingTypes = false);
    }
  }

  Future<void> _loadProductsForItem(InvoiceItemDraft item) async {
    if (item.selectedType == null) return;
    final categoryCode = item.selectedType!.code;
    
    if (_categoryProductCache.containsKey(categoryCode)) {
      setState(() {
        item.availableProducts = _categoryProductCache[categoryCode]!;
      });
      return;
    }

    setState(() => item.isLoadingProducts = true);
    try {
      final response = await ApiClient().get('/product?type=$categoryCode&availableForSale=true');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final products = data.map((json) => Product.fromJson(json)).toList();
        _categoryProductCache[categoryCode] = products;
        setState(() {
          item.availableProducts = products;
          item.isLoadingProducts = false;
        });
      }
    } catch (e) {
      setState(() => item.isLoadingProducts = false);
    }
  }

  Future<List<Partner>> _searchPartners(String query) async {
    if (query.length < 2) return [];
    try {
      final response = await ApiClient().get('/v2/partner?query=$query');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Partner.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error searching partners: $e');
    }
    return [];
  }

  void _addItem() {
    final newItem = InvoiceItemDraft(
      selectedType: _productTypes.isNotEmpty ? _productTypes.first : null,
    );
    setState(() {
      _items.add(newItem);
    });
    if (newItem.selectedType != null) {
      _loadProductsForItem(newItem);
    }
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items[index].dispose();
        _items.removeAt(index);
      });
    }
  }

  double _calculateLineVat(InvoiceItemDraft item) {
    if (!item.applyVat) return 0.0;
    final qty = double.tryParse(item.quantityController.text) ?? 0;
    final price = double.tryParse(item.amountController.text) ?? 0;
    final discount = double.tryParse(item.discountController.text) ?? 0;
    
    final discountedPrice = price * (1 - (discount / 100));
    final lineAmount = qty * discountedPrice;

    if (_isVatInclusive) {
      final lineExcVat = lineAmount / (1 + (_vatRate / 100));
      return lineAmount - lineExcVat;
    } else {
      return lineAmount * (_vatRate / 100);
    }
  }

  Map<String, double> _calculateTotals() {
    double totalVatAmount = 0;
    double totalIncVat = 0;
    double totalExcVat = 0;
    double totalDiscount = 0;

    for (var item in _items) {
      final qty = double.tryParse(item.quantityController.text) ?? 0;
      final price = double.tryParse(item.amountController.text) ?? 0;
      final discountPercent = double.tryParse(item.discountController.text) ?? 0;
      
      if (item.productController.text.isEmpty && price == 0) continue;

      final grossLineAmount = qty * price;
      final discountAmount = grossLineAmount * (discountPercent / 100);
      final netLineAmount = grossLineAmount - discountAmount;
      
      totalDiscount += discountAmount;

      if (item.applyVat) {
        if (_isVatInclusive) {
          final lineIncVat = netLineAmount;
          final lineExcVat = lineIncVat / (1 + (_vatRate / 100));
          final lineVat = lineIncVat - lineExcVat;
          
          totalIncVat += lineIncVat;
          totalExcVat += lineExcVat;
          totalVatAmount += lineVat;
        } else {
          final lineExcVat = netLineAmount;
          final lineVat = lineExcVat * (_vatRate / 100);
          final lineIncVat = lineExcVat + lineVat;
          
          totalIncVat += lineIncVat;
          totalExcVat += lineExcVat;
          totalVatAmount += lineVat;
        }
      } else {
        totalIncVat += netLineAmount;
        totalExcVat += netLineAmount;
      }
    }

    return {
      'subtotal': totalExcVat,
      'vatAmount': totalVatAmount,
      'totalIncVat': totalIncVat,
      'totalExcVat': totalExcVat,
      'discountAmount': totalDiscount,
    };
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate() || _selectedPartner == null) {
      if (_selectedPartner == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a customer'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }

    final List<InvoiceItemDraft> filledItems = _items.where((item) {
      final price = double.tryParse(item.amountController.text) ?? 0;
      return item.productController.text.isNotEmpty || price > 0;
    }).toList();

    if (filledItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final totals = _calculateTotals();
      
      final List<Map<String, dynamic>> linesPayload = filledItems.map((item) {
        final qty = double.tryParse(item.quantityController.text) ?? 0;
        final price = double.tryParse(item.amountController.text) ?? 0;
        final discountPercent = double.tryParse(item.discountController.text) ?? 0;

        final grossAmount = qty * price;
        final discountAmount = grossAmount * (discountPercent / 100);
        final netAmount = grossAmount - discountAmount;

        double lineTax = 0;
        double lineSubtotal = 0;
        double lineTotal = 0;

        if (item.applyVat) {
          if (_isVatInclusive) {
            lineTotal = netAmount;
            lineSubtotal = lineTotal / (1 + (_vatRate / 100));
            lineTax = lineTotal - lineSubtotal;
          } else {
            lineSubtotal = netAmount;
            lineTax = lineSubtotal * (_vatRate / 100);
            lineTotal = lineSubtotal + lineTax;
          }
        } else {
          lineSubtotal = netAmount;
          lineTotal = netAmount;
          lineTax = 0;
        }

        return {
          "productId": item.productId,
          "description": item.descriptionController.text,
          "quantity": qty,
          "unitPriceCents": (price * 100).round(),
          "discountCents": (discountAmount * 100).round(),
          "taxCents": (lineTax * 100).round(),
          "subtotalCents": (lineSubtotal * 100).round(),
          "totalCents": (lineTotal * 100).round(),
        };
      }).toList();

      final payload = {
        "id": widget.existingInvoice?.id,
        "partnerId": _selectedPartner!.id,
        "invoiceDate": DateFormat('yyyy-MM-dd').format(_invoiceDate),
        "dueDate": DateFormat('yyyy-MM-dd').format(_dueDate),
        "externalRef": _referenceController.text,
        "subtotalCents": (totals['subtotal']! * 100).round(),
        "taxCents": (totals['vatAmount']! * 100).round(),
        "discountCents": (totals['discountAmount']! * 100).round(),
        "totalCents": (totals['totalIncVat']! * 100).round(),
        "currency": "ZAR",
        "lines": linesPayload,
        "status": widget.existingInvoice?.status ?? "DRAFT",
      };

      final response = widget.existingInvoice == null 
        ? await ApiClient().post('/v2/invoice', body: payload)
        : await ApiClient().post('/v2/invoice/${widget.existingInvoice!.id}', body: payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final String? createdId = responseData['id'];

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invoice ${widget.existingInvoice == null ? "created" : "updated"} successfully'), behavior: SnackBarBehavior.floating),
          );
          
          if (widget.existingInvoice == null && createdId != null) {
            // Navigate to details for new invoice
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => InvoiceDetailScreen(invoiceId: createdId))
            );
          } else {
            Navigator.of(context).pop(true);
          }
        }
      } else {
        throw AppException('Failed to save invoice: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Error: $e')), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.existingInvoice == null ? 'Create Invoice' : 'Edit Invoice'),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: false,
      ),
      body: _isLoadingTypes 
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(Icons.person, 'Customer Information'),
                          const SizedBox(height: 8),
                          _buildCustomerSection(colorScheme),
                          const SizedBox(height: 16),

                          _buildSectionHeader(Icons.description, 'General Details'),
                          const SizedBox(height: 8),
                          _buildGeneralDetailsCard(colorScheme),
                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionHeader(Icons.list_alt, 'Invoice Items'),
                              TextButton.icon(
                                onPressed: _addItem,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add Item', style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildItemHeaderRow(),
                          ...List.generate(_items.length, (index) => _buildItemForm(index)),
                          const SizedBox(height: 100), // Space for bottom summary
                        ],
                      ),
                    ),
                  ),
                  _buildBottomSummary(colorScheme),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildItemHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const SizedBox(width: 18, child: Text('#', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
          const Expanded(flex: 25, child: Text('CATEGORY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
          const SizedBox(width: 4),
          const Expanded(flex: 30, child: Text('PRODUCT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
          const SizedBox(width: 4),
          const Expanded(flex: 40, child: Text('DESCRIPTION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
          const SizedBox(width: 4),
          const Expanded(flex: 25, child: Text('PRICE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
          const SizedBox(width: 4),
          const SizedBox(width: 30, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
          const SizedBox(width: 4),
          const SizedBox(width: 35, child: Text('DISC%', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
          const SizedBox(width: 4),
          const Expanded(flex: 20, child: Text('VAT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
          const SizedBox(width: 28), // Space for delete icon
        ],
      ),
    );
  }

  Widget _buildCustomerSection(ColorScheme colorScheme) {
    return Column(
      children: [
        _buildCustomerSearch(),
        if (_selectedPartner != null) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.primaryContainer.withOpacity(0.3)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                child: const Icon(Icons.person, size: 16),
              ),
              title: Text(
                _selectedPartner!.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: Text(
                'No: ${_selectedPartner!.number} • ID: ${_selectedPartner!.identityNumber}',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _selectedPartner = null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGeneralDetailsCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            TextFormField(
              controller: _referenceController,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                labelText: 'Reference',
                prefixIcon: const Icon(Icons.tag, size: 16),
                filled: true,
                fillColor: Colors.grey[50],
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildDatePickerField('Invoice Date', _invoiceDate, (date) => setState(() => _invoiceDate = date))),
                const SizedBox(width: 8),
                Expanded(child: _buildDatePickerField('Due Date', _dueDate, (date) => setState(() => _dueDate = date))),
              ],
            ),
            const SizedBox(height: 10),
            _buildVatPricingRow(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerField(String label, DateTime date, Function(DateTime) onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2000),
              lastDate: DateTime(2101),
            );
            if (picked != null) onPicked(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month, size: 14, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  DateFormat('yyyy-MM-dd').format(date),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVatPricingRow(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colorScheme.secondaryContainer.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.percent, size: 14, color: colorScheme.secondary),
              const SizedBox(width: 6),
              const Text('VAT Pricing', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
            ],
          ),
          Row(
            children: [
              Text('Excl.', style: TextStyle(fontSize: 10, color: !_isVatInclusive ? colorScheme.secondary : Colors.grey)),
              Switch.adaptive(
                value: _isVatInclusive,
                onChanged: (val) => setState(() => _isVatInclusive = val),
                activeColor: colorScheme.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Text('Incl.', style: TextStyle(fontSize: 10, color: _isVatInclusive ? colorScheme.secondary : Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSearch() {
    return SearchAnchor(
      builder: (context, controller) {
        return SearchBar(
          controller: controller,
          onTap: () => controller.openView(),
          onChanged: (_) => controller.openView(),
          leading: Icon(Icons.search, color: Theme.of(context).colorScheme.primary, size: 18),
          hintText: 'Search for a customer...',
          elevation: const WidgetStatePropertyAll(0),
          side: WidgetStatePropertyAll(BorderSide(color: Colors.grey.shade300)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          constraints: const BoxConstraints(minHeight: 36, maxHeight: 36),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 12)),
        );
      },
      suggestionsBuilder: (context, controller) async {
        final partners = await _searchPartners(controller.text);
        if (partners.isEmpty) return [const ListTile(title: Text('No customers found'))];
        return partners.map((partner) {
          return ListTile(
            dense: true,
            leading: const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
            title: Text(partner.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            subtitle: Text('No: ${partner.number}', style: const TextStyle(fontSize: 10)),
            onTap: () {
              setState(() {
                _selectedPartner = partner;
                controller.closeView(partner.fullName);
              });
            },
          );
        }).toList();
      },
    );
  }

  Widget _buildItemForm(int index) {
    final item = _items[index];
    final lineVat = _calculateLineVat(item);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
          right: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Index
          SizedBox(
            width: 18,
            child: Text('${index + 1}', 
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey[400])),
          ),
          
          // Category
          Expanded(flex: 25, child: _buildItemCategoryDropdown(item)),
          const SizedBox(width: 4),
          
          // Product
          Expanded(flex: 30, child: _buildProductSearchForItem(item)),
          const SizedBox(width: 4),
          
          // Description
          Expanded(flex: 40, child: TextFormField(
            controller: item.descriptionController,
            style: const TextStyle(fontSize: 10),
            decoration: InputDecoration(
              hintText: 'Description',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            ),
          )),
          const SizedBox(width: 4),
          
          // Price
          Expanded(flex: 25, child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: item.amountController,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Price',
                  prefixText: 'R',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              Text('VAT:${lineVat.toStringAsFixed(1)}', 
                style: const TextStyle(fontSize: 7, color: Colors.green, height: 1.0, fontWeight: FontWeight.bold)),
            ],
          )),
          const SizedBox(width: 4),
          
          // Qty
          SizedBox(width: 30, child: TextFormField(
            controller: item.quantityController,
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'Qty',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          )),
          const SizedBox(width: 4),

          // Discount %
          SizedBox(width: 35, child: TextFormField(
            controller: item.discountController,
            style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '%',
              suffixText: '%',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          )),
          const SizedBox(width: 4),

          // VAT (Read Only Column)
          Expanded(flex: 20, child: Container(
            height: 28, // Matches input height
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              'V:${lineVat.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 8, color: Colors.green, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          )),
          
          // Delete
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red, size: 14),
            onPressed: () => _removeItem(index),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, maxWidth: 28),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildItemCategoryDropdown(InvoiceItemDraft item) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProductType>(
          isExpanded: true,
          value: item.selectedType,
          style: const TextStyle(fontSize: 9, color: Colors.black),
          hint: const Text('Type', style: TextStyle(fontSize: 9)),
          items: _productTypes.map((type) {
            return DropdownMenuItem(value: type, child: Text(type.description, overflow: TextOverflow.ellipsis));
          }).toList(),
          onChanged: (val) {
            setState(() {
              item.selectedType = val;
              item.productId = null;
              item.productController.clear();
              item.descriptionController.clear();
              item.amountController.clear();
              _loadProductsForItem(item);
            });
          },
        ),
      ),
    );
  }

  Widget _buildProductSearchForItem(InvoiceItemDraft item) {
    return SearchAnchor(
      builder: (context, controller) {
        return SearchBar(
          controller: controller,
          onTap: () => controller.openView(),
          onChanged: (_) => controller.openView(),
          hintText: item.productController.text.isEmpty ? 'Product' : item.productController.text,
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          side: WidgetStatePropertyAll(BorderSide(color: Colors.grey.shade300)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
          constraints: const BoxConstraints(minHeight: 28, maxHeight: 28),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 9)),
        );
      },
      suggestionsBuilder: (context, controller) {
        if (item.isLoadingProducts) {
          return [const Center(child: Padding(padding: EdgeInsets.all(4.0), child: CircularProgressIndicator(strokeWidth: 2)))];
        }

        final query = controller.text.toLowerCase();
        final filtered = item.availableProducts.where((p) => 
          p.code.toLowerCase().contains(query) || 
          p.description.toLowerCase().contains(query)
        ).toList();

        if (filtered.isEmpty) return [const ListTile(title: Text('No products found', style: TextStyle(fontSize: 10)))];

        return filtered.map((p) {
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            title: Text(p.description, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            subtitle: Text('Code: ${p.code} • R ${p.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 9)),
            onTap: () {
              setState(() {
                item.productId = p.id;
                item.productController.text = p.code;
                item.descriptionController.text = p.description;
                item.amountController.text = p.price.toStringAsFixed(2);
                controller.closeView(p.code);
              });
            },
          );
        }).toList();
      },
    );
  }

  Widget _buildBottomSummary(ColorScheme colorScheme) {
    final totals = _calculateTotals();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: _buildSummaryLine('Subtotal', totals['totalExcVat']!)),
                const SizedBox(width: 16),
                Expanded(child: _buildSummaryLine('VAT', totals['vatAmount']!)),
              ],
            ),
            const Divider(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Grand Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text(
                  'R ${totals['totalIncVat']!.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _saveInvoice,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 1,
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(widget.existingInvoice == null ? 'CREATE INVOICE' : 'SAVE CHANGES', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryLine(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        Text('R ${value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  void dispose() {
    for (var item in _items) {
      item.dispose();
    }
    _referenceController.dispose();
    super.dispose();
  }
}
