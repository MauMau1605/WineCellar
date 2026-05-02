import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/wine_cellar/domain/entities/cellar_cell_position.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/helpers/expert_cellar_editor_helper.dart';

final _sourceCellar = VirtualCellarEntity(
  id: 5,
  name: 'Atelier',
  rows: 3,
  columns: 4,
  emptyCells: {
    const CellarCellPosition(row: 1, col: 2),
    const CellarCellPosition(row: 3, col: 4),
  },
  theme: VirtualCellarTheme.garageIndustrial,
);

void main() {
  group('ExpertCellarEditorHelper', () {
    test('construit la grille initiale depuis un cellier source', () {
      final grid = ExpertCellarEditorHelper.buildInitialGrid(
        initialRows: 2,
        initialColumns: 2,
        sourceCellar: _sourceCellar,
      );

      expect(grid, hasLength(3));
      expect(grid.first, hasLength(4));
      expect(grid[0][0], isTrue);
      expect(grid[0][1], isFalse);
      expect(grid[2][3], isFalse);
    });

    test('construit une grille pleine sans cellier source', () {
      final grid = ExpertCellarEditorHelper.buildInitialGrid(
        initialRows: 2,
        initialColumns: 3,
      );

      expect(grid, hasLength(2));
      expect(grid.first, hasLength(3));
      expect(grid.expand((row) => row), everyElement(isTrue));
    });

    test('génère le premier nom de cave disponible', () {
      expect(
        ExpertCellarEditorHelper.generateDefaultCellarName([
          'Cave 1',
          'cave 2',
          'Reserve',
        ]),
        'Cave 3',
      );
    });

    test('normalise et résout le nom effectif du cellier', () {
      expect(ExpertCellarEditorHelper.normalizeCellarName('  Atelier  '), 'Atelier');
      expect(
        ExpertCellarEditorHelper.resolveEffectiveCellarName('  ', ['Cave 1']),
        'Cave 2',
      );
      expect(
        ExpertCellarEditorHelper.resolveEffectiveCellarName('  Mon cellier  ', ['Cave 1']),
        'Mon cellier',
      );
    });

    test('reconstruit une grille vide selon les dimensions validées', () {
      final resetGrid = ExpertCellarEditorHelper.buildResetGrid(
        rowsText: '4',
        colsText: '5',
      );

      expect(resetGrid, isNotNull);
      expect(resetGrid, hasLength(4));
      expect(resetGrid!.first, hasLength(5));
      expect(resetGrid.expand((row) => row), everyElement(isTrue));
    });

    test('rejette les dimensions invalides pour la remise à zéro', () {
      expect(
        ExpertCellarEditorHelper.buildResetGrid(rowsText: '0', colsText: '5'),
        isNull,
      );
      expect(
        ExpertCellarEditorHelper.buildResetGrid(rowsText: '2', colsText: '31'),
        isNull,
      );
      expect(
        ExpertCellarEditorHelper.buildResetGrid(rowsText: 'x', colsText: '5'),
        isNull,
      );
    });

    test('extrait les cellules vides et le récapitulatif de validation', () {
      final grid = [
        [true, false, true],
        [false, true, true],
      ];

      expect(
        ExpertCellarEditorHelper.extractEmptyCells(grid),
        {
          const CellarCellPosition(row: 1, col: 2),
          const CellarCellPosition(row: 2, col: 1),
        },
      );
      expect(
        ExpertCellarEditorHelper.validationSummaryLines(grid),
        ['Dimensions: 2 x 3', 'Casiers actifs: 4', 'Zones vides: 2'],
      );
    });

    test('formate le résumé de sélection', () {
      expect(
        ExpertCellarEditorHelper.selectionSummaryLabel(
          rows: 3,
          cols: 4,
          selectedCount: 5,
        ),
        '3 x 4 - 5 selection',
      );
    });

    test('développe correctement les sélections cellules, ligne et colonne', () {
      expect(
        ExpertCellarEditorHelper.currentSelectionCells(
          selectionState: ExpertSelectionState.cells({(0, 1), (1, 2)}),
          rowCount: 3,
          colCount: 4,
        ),
        {(0, 1), (1, 2)},
      );
      expect(
        ExpertCellarEditorHelper.currentSelectionCells(
          selectionState: ExpertSelectionState.row(1),
          rowCount: 3,
          colCount: 4,
        ),
        {(1, 0), (1, 1), (1, 2), (1, 3)},
      );
      expect(
        ExpertCellarEditorHelper.currentSelectionCells(
          selectionState: ExpertSelectionState.column(2),
          rowCount: 3,
          colCount: 4,
        ),
        {(0, 2), (1, 2), (2, 2)},
      );
    });

    test('bascule la sélection de cellule et gère la sélection glissée', () {
      var selection = ExpertCellarEditorHelper.toggleCellSelection(
        selectionState: ExpertSelectionState.empty(),
        row: 1,
        col: 1,
      );
      expect(selection.type, ExpertSelectionType.cells);
      expect(selection.selectedCells, {(1, 1)});

      selection = ExpertCellarEditorHelper.toggleCellSelection(
        selectionState: selection,
        row: 1,
        col: 1,
      );
      expect(selection.type, ExpertSelectionType.none);
      expect(selection.selectedCells, isEmpty);

      final dragSelection = ExpertCellarEditorHelper.dragSelection(
        anchor: (1, 1),
        rowDelta: 2,
        colDelta: -1,
        rowCount: 4,
        colCount: 4,
      );
      expect(
        dragSelection.selectedCells,
        {(1, 0), (1, 1), (2, 0), (2, 1), (3, 0), (3, 1)},
      );
    });

    test('applique une valeur à une sélection et expose la barre d outils contextuelle', () {
      final grid = [
        [true, true],
        [true, true],
      ];

      expect(
        ExpertCellarEditorHelper.applySelectionValue(
          grid: grid,
          selectedCells: {(0, 1), (1, 0)},
          active: false,
        ),
        [
          [true, false],
          [false, true],
        ],
      );
      expect(
        ExpertCellarEditorHelper.shouldShowRowActions(
          ExpertSelectionState.row(0),
        ),
        isTrue,
      );
      expect(
        ExpertCellarEditorHelper.shouldShowColumnActions(
          ExpertSelectionState.column(0),
        ),
        isTrue,
      );
      expect(
        ExpertCellarEditorHelper.shouldShowRowActions(
          ExpertSelectionState.empty(),
        ),
        isFalse,
      );
    });

    test('insère et supprime lignes et colonnes en conservant la sélection cohérente', () {
      final grid = [
        [true, true],
        [false, true],
      ];

      final insertedRow = ExpertCellarEditorHelper.insertRow(
        grid: grid,
        selectionState: ExpertSelectionState.row(0),
        before: false,
      );
      expect(insertedRow, isNotNull);
      expect(insertedRow!.grid, [
        [true, true],
        [true, true],
        [false, true],
      ]);
      expect(insertedRow.selectionState.selectedRow, 1);

      final insertedColumn = ExpertCellarEditorHelper.insertColumn(
        grid: grid,
        selectionState: ExpertSelectionState.column(1),
        before: true,
      );
      expect(insertedColumn, isNotNull);
      expect(insertedColumn!.grid, [
        [true, true, true],
        [false, true, true],
      ]);
      expect(insertedColumn.selectionState.selectedCol, 1);

      final deletedRow = ExpertCellarEditorHelper.deleteRow(
        grid: [
          [true, true],
          [false, true],
          [true, false],
        ],
        selectionState: ExpertSelectionState.row(2),
      );
      expect(deletedRow, isNotNull);
      expect(deletedRow!.grid, [
        [true, true],
        [false, true],
      ]);
      expect(deletedRow.selectionState.selectedRow, 1);

      final deletedColumn = ExpertCellarEditorHelper.deleteColumn(
        grid: [
          [true, false, true],
          [false, true, true],
        ],
        selectionState: ExpertSelectionState.column(1),
      );
      expect(deletedColumn, isNotNull);
      expect(deletedColumn!.grid, [
        [true, true],
        [false, true],
      ]);
      expect(deletedColumn.selectionState.selectedCol, 1);
    });

    test('gère l historique undo redo de manière pure', () {
      final baseGrid = [
        [true, true],
        [true, true],
      ];

      final pushed = ExpertCellarEditorHelper.pushUndoSnapshot(
        grid: baseGrid,
        undoStack: const [],
        redoStack: const [
          [
            [false],
          ],
        ],
      );
      expect(pushed.undoStack, hasLength(1));
      expect(pushed.redoStack, isEmpty);

      final undo = ExpertCellarEditorHelper.applyUndo(
        grid: [
          [false, true],
          [true, true],
        ],
        undoStack: pushed.undoStack,
        redoStack: pushed.redoStack,
      );
      expect(undo, isNotNull);
      expect(undo!.grid, baseGrid);
      expect(undo.undoStack, isEmpty);
      expect(undo.redoStack, hasLength(1));

      final redo = ExpertCellarEditorHelper.applyRedo(
        grid: undo.grid,
        undoStack: undo.undoStack,
        redoStack: undo.redoStack,
      );
      expect(redo, isNotNull);
      expect(redo!.grid, [
        [false, true],
        [true, true],
      ]);
      expect(redo.undoStack, hasLength(1));
      expect(redo.redoStack, isEmpty);
    });

    test('sérialise, relit et reconstruit un brouillon expert', () {
      final payload = ExpertCellarDraftPayload(
        name: 'Brouillon',
        rows: 2,
        cols: 3,
        emptyCells: {
          const CellarCellPosition(row: 1, col: 2),
          const CellarCellPosition(row: 2, col: 1),
        },
      );

      final reparsed = ExpertCellarDraftPayload.tryParse(payload.toJsonString());
      expect(reparsed, isNotNull);
      expect(reparsed!.name, 'Brouillon');
      expect(reparsed.rows, 2);
      expect(reparsed.cols, 3);
      expect(reparsed.emptyCells, payload.emptyCells);
      expect(
        reparsed.toGrid(),
        [
          [true, false, true],
          [false, true, true],
        ],
      );
      expect(ExpertCellarDraftPayload.tryParse('not-json'), isNull);
      expect(
        ExpertCellarDraftPayload.tryParse('{"rows":0,"cols":2}'),
        isNull,
      );
    });

    test('construit le cellier validé final à partir de la grille', () {
      final entity = ExpertCellarEditorHelper.buildValidatedCellarEntity(
        grid: [
          [true, false],
          [true, true],
        ],
        effectiveName: 'Expert 1',
        theme: VirtualCellarTheme.premiumCave,
        now: DateTime(2026, 5, 2),
        sourceCellar: _sourceCellar,
      );

      expect(entity.id, 5);
      expect(entity.name, 'Expert 1');
      expect(entity.rows, 2);
      expect(entity.columns, 2);
      expect(entity.theme, VirtualCellarTheme.premiumCave);
      expect(entity.createdAt, _sourceCellar.createdAt);
      expect(entity.updatedAt, DateTime(2026, 5, 2));
      expect(
        entity.emptyCells,
        {const CellarCellPosition(row: 1, col: 2)},
      );
    });
  });
}