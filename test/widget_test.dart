import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/core/theme/app_theme.dart';
import 'package:mawa_erp/core/theme/mawa_design.dart';
import 'package:mawa_erp/core/widgets/mawa_ui.dart';

void main() {
  testWidgets('MAWA design system renders professional shared surfaces',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(24),
            child: MawaSurface(
              child: MawaPageHeader(
                title: 'Membership Management',
                description: 'Manage the complete member lifecycle.',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Membership Management'), findsOneWidget);
    expect(find.text('Manage the complete member lifecycle.'), findsOneWidget);
    expect(find.byType(MawaSurface), findsOneWidget);

    final BuildContext context = tester.element(find.byType(Scaffold));
    expect(Theme.of(context).scaffoldBackgroundColor, MawaDesign.page);
    expect(Theme.of(context).colorScheme.primary, MawaDesign.red);
  });

  test('responsive grid sizing keeps card widths consistent', () {
    expect(MawaDesign.responsiveGridCount(320), 1);
    expect(MawaDesign.responsiveGridCount(760), 3);
    expect(
      MawaDesign.responsiveGridCount(1800, maxColumns: 5),
      5,
    );
  });
}
