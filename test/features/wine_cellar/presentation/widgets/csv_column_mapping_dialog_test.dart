import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/csv_column_mapping_dialog.dart';

void main() {
  testWidgets('retourne un mapping valide quand la colonne nom est renseignée',
      (tester) async {
    CsvMappingDialogResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showDialog<CsvMappingDialogResult>(
                      context: context,
                      builder: (_) => const CsvColumnMappingDialog(),
                    );
                  },
                  child: const Text('ouvrir'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Nom *'), '1');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.mapping.name, 1);
    expect(result!.hasHeader, isTrue);
  });
}
