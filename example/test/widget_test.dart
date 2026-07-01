import 'package:flutter_test/flutter_test.dart';

import 'package:seo_seed_example/main.dart';

void main() {
  testWidgets('renders the seeded content in the app', (tester) async {
    await tester.pumpWidget(const DemoApp());

    expect(find.text('Simple pricing'), findsOneWidget);
    expect(find.text('Splitting rent fairly'), findsOneWidget);
  });
}
