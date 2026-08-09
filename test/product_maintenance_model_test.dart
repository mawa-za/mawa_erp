import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/features/products/models/product_maintenance.dart';

void main() {
  test('normalises legacy selling price code', () {
    final product = ProductMaintenanceItem.fromJson({
      'id': 'product-1',
      'code': 'GS-COVER',
      'description': 'Group Society Cover',
      'pricings': [
        {
          'pricing': {'code': 'SELLING_PRICE', 'description': 'Selling Price'},
          'value': 125.50,
        },
      ],
    });

    expect(product.pricingType, 'SELLING-PRICE');
    expect(product.price, 125.50);
  });
}
