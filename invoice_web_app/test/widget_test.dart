import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_web_app/main.dart';

void main() {
  testWidgets('Invoice Scanner app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const InvoiceWebApp());
    expect(find.text('Invoice Scanner'), findsOneWidget);
  });
}
