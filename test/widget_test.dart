import 'package:flutter_test/flutter_test.dart';

import 'package:sick_of_football/main.dart';

void main() {
  testWidgets('displays the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Sick of football'), findsOneWidget);
    expect(find.text('Adres E-mail'), findsOneWidget);
    expect(find.text('Hasło'), findsOneWidget);
    expect(find.text('Zaloguj się'), findsOneWidget);
  });
}
