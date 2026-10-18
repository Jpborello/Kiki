import 'package:flutter_test/flutter_test.dart';
import 'package:kikidraw/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KikiDrawApp());
    expect(find.text('¡Hola, Kiara Zoe! 👑🎨'), findsOneWidget);
  });
}
