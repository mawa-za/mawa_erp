import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';

class InvoiceItemDraft {
  final TextEditingController productController;
  final TextEditingController descriptionController;
  final TextEditingController amountController;
  final TextEditingController quantityController;
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
    this.productId,
    this.selectedType,
    this.applyVat = true,
  })  : productController = TextEditingController(text: product),
        descriptionController = TextEditingController(text: description),
        amountController = TextEditingController(text: amount),
        quantityController = TextEditingController(text: quantity);

  void dispose() {
    productController.dispose();
    descriptionController.dispose();
    amountController.dispose();
    quantityController.dispose();
  }
}

class Partner {
  final String id;
  final String number;
  final String firstName;
  final String lastName;
  final String identityNumber;

  Partner({
    required this.id,
    required this.number,
    required this.firstName,
    required this.lastName,
    required this.identityNumber,
  });

  String get fullName => '$firstName $lastName';

  factory Partner.fromJson(Map<String, dynamic> json) {
    return Partner(
      id: json['partnerId'] ?? '',
      number: json['partnerNo'] ?? '',
      firstName: json['name2'] ?? '',
      lastName: json['name1'] ?? '',
      identityNumber: json['identityNumber'] ?? '',
    );
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
      description: json['description'] ?? '',
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
      description: json['description'] ?? '',
    );
  }
}

class InvoiceCreateScreen extends StatefulWidget {
  const InvoiceCreateScreen({super.key});

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
  }

  Future<void> _fetchProductTypes() async {
    try {
      final response = await ApiClient().get('/field/PRODUCT-TYPE/option');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _productTypes = data.map((json) => ProductType.fromJson(json)).toList();
          _isLoadingTypes = false;
          _addItem();
        });
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
      final response = await ApiClient().get('/product?type=$categoryCode');
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
    final lineAmount = qty * price;

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
    double subtotal = 0;

    for (var item in _items) {
      final qty = double.tryParse(item.quantityController.text) ?? 0;
      final price = double.tryParse(item.amountController.text) ?? 0;
      final lineAmount = qty * price;
      subtotal += lineAmount;

      if (item.applyVat) {
        if (_isVatInclusive) {
          final lineIncVat = lineAmount;
          final lineExcVat = lineIncVat / (1 + (_vatRate / 100));
          final lineVat = lineIncVat - lineExcVat;
          
          totalIncVat += lineIncVat;
          totalExcVat += lineExcVat;
          totalVatAmount += lineVat;
        } else {
          final lineExcVat = lineAmount;
          final lineVat = lineExcVat * (_vatRate / 100);
          final lineIncVat = lineExcVat + lineVat;
          
          totalIncVat += lineIncVat;
          totalExcVat += lineExcVat;
          totalVatAmount += lineVat;
        }
      } else {
        totalIncVat += lineAmount;
        totalExcVat += lineAmount;
      }
    }

    return {
      'subtotal': subtotal,
      'vatAmount': totalVatAmount,
      'totalIncVat': totalIncVat,
      'totalExcVat': totalExcVat,
    };
  }

  Future<void> _createInvoice() async {
    if (!_formKey.currentState!.validate() || _selectedPartner == null) {
      if (_selectedPartner == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a customer')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      
      final String isoInvoiceDate = _invoiceDate.toUtc().toIso8601String();
      final String isoDueDate = _dueDate.toUtc().toIso8601String();
      final totals = _calculateTotals();
      
      final List<Map<String, dynamic>> itemsPayload = _items.map((item) {
        final qty = double.tryParse(item.quantityController.text) ?? 0;
        final price = double.tryParse(item.amountController.text) ?? 0;
        return {
          "productId": item.productId,
          "code": item.productController.text,
          "description": item.descriptionController.text,
          "quantity": qty,
          "unitPrice": price,
          "lineTotal": qty * price,
        };
      }).toList();

      final payload = {
        "customerId": _selectedPartner!.id,
        "salesRepresentative": userId,
        "dueDate": isoDueDate,
        "invoiceDate": isoInvoiceDate,
        "paymentTerms": "IMMEDIATE",
        "pricing": {
          "totalExcVat": totals['totalExcVat'],
          "totalIncVat": totals['totalIncVat'],
          "discountAmount": 0,
          "discountPercentage": 0,
          "items": itemsPayload,
          "vatamount": totals['vatAmount'],
          "vatpercentage": _vatRate
        },
        "items": itemsPayload,
        "invoiceType": "INVOICE",
        "transactionSubType": "STANDARD"
      };

      final response = await ApiClient().post('/v2/invoice', body: payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice created successfully')),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Failed to create invoice: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
      appBar: AppBar(
        title: const Text('Create Invoice'),
      ),
      body: _isLoadingTypes 
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Customer Search'),
                          _buildCustomerSearch(),
                          if (_selectedPartner != null) ...[
                            const SizedBox(height: 8),
                            Card(
                              elevation: 0,
                              color: colorScheme.primaryContainer.withOpacity(0.2),
                              child: ListTile(
                                leading: const Icon(Icons.person),
                                title: Text(_selectedPartner!.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('ID: ${_selectedPartner!.identityNumber} | No: ${_selectedPartner!.number}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setState(() => _selectedPartner = null),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildInvoiceDatePicker()),
                              const SizedBox(width: 8),
                              Expanded(child: _buildDueDatePicker()),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildVatToggle(),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionTitle('Invoice Items'),
                              TextButton.icon(
                                onPressed: _addItem,
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                label: const Text('Add Item'),
                                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                              ),
                            ],
                          ),
                          ...List.generate(_items.length, (index) => _buildItemForm(index)),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomSummary(),
                ],
              ),
            ),
    );
  }

  Widget _buildVatToggle() {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('VAT Pricing', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Row(
            children: [
              const Text('Excl', style: TextStyle(fontSize: 11)),
              Switch(
                value: _isVatInclusive,
                onChanged: (val) => setState(() => _isVatInclusive = val),
                activeColor: Theme.of(context).colorScheme.primary,
              ),
              const Text('Incl', style: TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _buildCustomerSearch() {
    return SearchAnchor(
      builder: (BuildContext context, SearchController controller) {
        return SearchBar(
          controller: controller,
          padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.symmetric(horizontal: 16.0)),
          onTap: () => controller.openView(),
          onChanged: (_) => controller.openView(),
          leading: const Icon(Icons.search),
          hintText: 'Search customer...',
          elevation: const WidgetStatePropertyAll(1),
          constraints: const BoxConstraints(minHeight: 45, maxHeight: 45),
        );
      },
      suggestionsBuilder: (BuildContext context, SearchController controller) async {
        final partners = await _searchPartners(controller.text);
        return partners.map((partner) {
          return ListTile(
            title: Text(partner.fullName),
            subtitle: Text('No: ${partner.number} | ID: ${partner.identityNumber}'),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Text('Item ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                const Text('VAT', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Checkbox(
                  value: item.applyVat,
                  onChanged: (val) {
                    setState(() {
                      item.applyVat = val ?? true;
                    });
                  },
                  visualDensity: VisualDensity.compact,
                ),
                if (_items.length > 1)
                  InkWell(
                    onTap: () => _removeItem(index),
                    child: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildItemCategoryDropdown(item),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _buildProductSearchForItem(item),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: item.descriptionController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: item.amountController,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          prefixText: 'R ',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (v) => setState(() {}),
                        validator: (v) => v?.isEmpty ?? true ? 'Req' : null,
                      ),
                      if (item.applyVat)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 2),
                          child: Text(
                            'VAT: R ${lineVat.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w500),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: item.quantityController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() {}),
                    validator: (v) => v?.isEmpty ?? true ? 'Req' : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCategoryDropdown(InvoiceItemDraft item) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
        color: Colors.grey.shade50,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProductType>(
          isExpanded: true,
          value: item.selectedType,
          style: const TextStyle(fontSize: 12, color: Colors.black),
          hint: const Text('Category', style: TextStyle(fontSize: 12)),
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
          hintText: item.productController.text.isEmpty ? 'Search Product...' : item.productController.text,
          leading: const Icon(Icons.inventory_2_outlined, size: 16),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(Colors.grey.shade50),
          side: WidgetStatePropertyAll(BorderSide(color: Colors.grey.shade300)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
          constraints: const BoxConstraints(minHeight: 40, maxHeight: 40),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 13)),
        );
      },
      suggestionsBuilder: (context, controller) {
        if (item.isLoadingProducts) {
          return [const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))];
        }

        final query = controller.text.toLowerCase();
        final filtered = item.availableProducts.where((p) => 
          p.code.toLowerCase().contains(query) || 
          p.description.toLowerCase().contains(query)
        ).toList();

        if (filtered.isEmpty) {
          return [const ListTile(title: Text('No products found'))];
        }

        return filtered.map((p) {
          return ListTile(
            title: Text(p.description, style: const TextStyle(fontSize: 13)),
            subtitle: Text('Code: ${p.code} | R ${p.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
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

  Widget _buildBottomSummary() {
    final totals = _calculateTotals();
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSummaryRow('Net Total (Excl. VAT)', 'R ${totals['totalExcVat']!.toStringAsFixed(2)}'),
          _buildSummaryRow('Total VAT', 'R ${totals['vatAmount']!.toStringAsFixed(2)}'),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              Text('R ${totals['totalIncVat']!.toStringAsFixed(2)}', 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _createInvoice,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: _isSubmitting 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('SUBMIT INVOICE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildInvoiceDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Invoice Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _invoiceDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2101),
            );
            if (picked != null && picked != _invoiceDate) {
              setState(() => _invoiceDate = picked);
            }
          },
          child: Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 8),
                Text(DateFormat('yyyy-MM-dd').format(_invoiceDate), style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDueDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Due Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _dueDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2101),
            );
            if (picked != null && picked != _dueDate) {
              setState(() => _dueDate = picked);
            }
          },
          child: Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 8),
                Text(DateFormat('yyyy-MM-dd').format(_dueDate), style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    for (var item in _items) {
      item.dispose();
    }
    super.dispose();
  }
}
