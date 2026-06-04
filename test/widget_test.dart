import 'package:flutter_test/flutter_test.dart';
import 'package:affiliate_wallet/main.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(const AffiliateWalletApp());
    expect(find.byType(AffiliateWalletApp), findsOneWidget);
  });
}
