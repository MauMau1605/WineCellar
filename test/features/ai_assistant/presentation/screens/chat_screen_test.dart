import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/screens/chat_screen.dart';

void main() {
  setUp(() {
    ChatScreen.pendingPrefill = null;
  });

  group('ChatScreen', () {
    testWidgets(
      'affiche la banniere de configuration et navigue vers les parametres',
      (tester) async {
        final router = await _pumpChatScreen(tester);

        expect(find.text('Assistant IA'), findsOneWidget);
        expect(
          find.text(
            'Configurez votre clé API dans les paramètres pour utiliser l\'assistant IA.',
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('Paramètres'));
        await tester.pumpAndSettle();

        expect(find.text('Écran paramètres factice'), findsOneWidget);

        router.go('/chat');
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'consomme le prefill et remplit le champ sans envoi si l IA est indisponible',
      (tester) async {
        ChatScreen.pendingPrefill = const PrefillData(
          displayText: 'Préremplissage cave',
          aiPrompt: 'Prompt interne complet',
        );

        await _pumpChatScreen(tester);
        await tester.pump();
        await tester.pump();

        expect(ChatScreen.pendingPrefill, isNull);
        expect(find.text('Préremplissage cave'), findsOneWidget);
        expect(find.text('Prompt interne complet'), findsNothing);
      },
    );
  });
}

Future<GoRouter> _pumpChatScreen(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/chat',
    routes: [
      GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Écran paramètres factice')),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiServiceProvider.overrideWith((ref) => null),
        analyzeWineUseCaseProvider.overrideWith((ref) => null),
        geminiWebSearchServiceProvider.overrideWith((ref) => null),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}
