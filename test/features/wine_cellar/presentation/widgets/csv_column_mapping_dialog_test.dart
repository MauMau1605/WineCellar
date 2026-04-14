import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/csv_column_mapping_dialog.dart';

void main() {
  testWidgets(
      'auto-détecte le mapping depuis les en-têtes et retourne headerLine',
      (tester) async {
    CsvMappingDialogResult? result;

    final previewRows = [
      ['Nom', 'Millésime', 'Producteur'],
      ['Château Margaux', '2015', 'Domaine X'],
    ];

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
                      builder: (_) =>
                          CsvColumnMappingDialog(previewRows: previewRows),
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

    // Auto-detection should have assigned 'name' from the "Nom" header.
    // Just tap Valider to confirm.
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.mapping.name, 1);
    expect(result!.mapping.vintage, 2);
    expect(result!.mapping.producer, 3);
    expect(result!.headerLine, 1);
  });

  testWidgets('retourne null quand le mapping n\'a pas le champ nom',
      (tester) async {
    CsvMappingDialogResult? result;

    final previewRows = [
      ['Région', 'Pays'],
      ['Bordeaux', 'France'],
    ];

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
                      builder: (_) =>
                          CsvColumnMappingDialog(previewRows: previewRows),
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

    // Try to validate without 'name' field — dialog should show a snackbar
    // and NOT close.
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    // Dialog should still be open (name is required).
    expect(find.text('Mapping des colonnes CSV'), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('annulation retourne null', (tester) async {
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

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
