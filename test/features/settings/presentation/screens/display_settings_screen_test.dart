import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wine_cellar/core/constants.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/settings/presentation/screens/display_settings_screen.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('DisplaySettingsScreen', () {
    late _MockSecureStorage storage;

    setUp(() {
      storage = _MockSecureStorage();
      when(() => storage.read(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        final key = invocation.namedArguments[#key] as String;
        return {
          AppConstants.keyWineListLayout: WineListLayout.list.name,
          AppConstants.keyHighlightLastConsumptionYear: 'false',
          AppConstants.keyHighlightPastOptimalConsumption: 'true',
        }[key];
      });
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => storage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});
    });

    testWidgets('charge les preferences et persiste les interactions', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [secureStorageProvider.overrideWithValue(storage)],
          child: const MaterialApp(home: DisplaySettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Affichage'), findsOneWidget);
      expect(find.text('Disposition de la cave'), findsOneWidget);
      expect(find.text('Thème visuel'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Maître-détail vertical'), 100);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Maître-détail vertical'));
      await tester.pumpAndSettle();

      verify(
        () => storage.write(
          key: AppConstants.keyWineListLayout,
          value: WineListLayout.masterDetailVertical.name,
        ),
      ).called(1);

      await tester.scrollUntilVisible(
        find.text('Alertes de consommation'),
        200,
      );
      await tester.pumpAndSettle();

      expect(find.text('Alertes de consommation'), findsOneWidget);
      expect(find.text('Derniere annee de consommation'), findsOneWidget);

      await tester.tap(find.text('Derniere annee de consommation'));
      await tester.pumpAndSettle();

      verify(
        () => storage.write(
          key: AppConstants.keyHighlightLastConsumptionYear,
          value: 'true',
        ),
      ).called(1);

      await tester.tap(find.text('Fenetre optimale depassee'));
      await tester.pumpAndSettle();

      verify(
        () => storage.write(
          key: AppConstants.keyHighlightPastOptimalConsumption,
          value: 'false',
        ),
      ).called(1);
    });
  });
}
