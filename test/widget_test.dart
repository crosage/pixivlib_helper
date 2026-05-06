import 'package:flutter_test/flutter_test.dart';
import 'package:tagselector/main.dart';

void main() {
  testWidgets('app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const PixivHelperApp());
    expect(find.byType(PixivHelperApp), findsOneWidget);
  });
}
