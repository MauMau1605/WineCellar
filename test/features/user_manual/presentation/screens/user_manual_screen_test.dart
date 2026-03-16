import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/user_manual/presentation/screens/user_manual_screen.dart';

void main() {
  testWidgets('ouvre directement la section tokens IA', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UserManualScreen(initialSection: UserManualSection.aiTokens),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Creation des tokens et appairage IA'), findsOneWidget);
    expect(find.text('Etapes communes'), findsOneWidget);
  });
}
