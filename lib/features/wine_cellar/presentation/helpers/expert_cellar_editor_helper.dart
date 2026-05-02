import 'dart:convert';

import 'package:wine_cellar/features/wine_cellar/domain/entities/cellar_cell_position.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';

enum ExpertSelectionType { none, cells, row, column }

class ExpertSelectionState {
  final ExpertSelectionType type;
  final Set<(int, int)> selectedCells;
  final int? selectedRow;
  final int? selectedCol;

  ExpertSelectionState({
    required this.type,
    Set<(int, int)> selectedCells = const <(int, int)>{},
    this.selectedRow,
    this.selectedCol,
  }) : selectedCells = Set<(int, int)>.from(selectedCells);

  factory ExpertSelectionState.empty() {
    return ExpertSelectionState(type: ExpertSelectionType.none);
  }

  factory ExpertSelectionState.cells(Set<(int, int)> selectedCells) {
    return ExpertSelectionState(
      type: selectedCells.isEmpty
          ? ExpertSelectionType.none
          : ExpertSelectionType.cells,
      selectedCells: selectedCells,
    );
  }

  factory ExpertSelectionState.row(int row) {
    return ExpertSelectionState(
      type: ExpertSelectionType.row,
      selectedRow: row,
    );
  }

  factory ExpertSelectionState.column(int col) {
    return ExpertSelectionState(
      type: ExpertSelectionType.column,
      selectedCol: col,
    );
  }
}

class ExpertCellarEditorHelper {
  ExpertCellarEditorHelper._();

  static const int maxSize = 30;

  static List<List<bool>> buildInitialGrid({
    required int initialRows,
    required int initialColumns,
    VirtualCellarEntity? sourceCellar,
  }) {
    final rows = sourceCellar?.rows ?? initialRows;
    final cols = sourceCellar?.columns ?? initialColumns;
    final grid = List<List<bool>>.generate(
      rows,
      (_) => List<bool>.filled(cols, true),
      growable: true,
    );

    if (sourceCellar == null) {
      return grid;
    }

    for (final cell in sourceCellar.emptyCells) {
      final row = cell.row - 1;
      final col = cell.col - 1;
      if (row >= 0 && row < rows && col >= 0 && col < cols) {
        grid[row][col] = false;
      }
    }

    return grid;
  }

  static String generateDefaultCellarName(Iterable<String> existingNames) {
    final lowerNames = existingNames.map((name) => name.toLowerCase()).toSet();
    for (var index = 1;; index++) {
      final candidate = 'Cave $index';
      if (!lowerNames.contains(candidate.toLowerCase())) {
        return candidate;
      }
    }
  }

  static String normalizeCellarName(String rawName) {
    return rawName.trim();
  }

  static String resolveEffectiveCellarName(
    String rawName,
    Iterable<String> existingNames,
  ) {
    final normalized = normalizeCellarName(rawName);
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return generateDefaultCellarName(existingNames);
  }

  static List<List<bool>>? buildResetGrid({
    required String rowsText,
    required String colsText,
    int maxGridSize = maxSize,
  }) {
    final rows = int.tryParse(rowsText.trim());
    final cols = int.tryParse(colsText.trim());
    if (rows == null || cols == null) return null;
    if (rows < 1 || cols < 1 || rows > maxGridSize || cols > maxGridSize) {
      return null;
    }

    return List<List<bool>>.generate(
      rows,
      (_) => List<bool>.filled(cols, true),
      growable: true,
    );
  }

  static Set<CellarCellPosition> extractEmptyCells(List<List<bool>> grid) {
    final cells = <CellarCellPosition>{};
    for (var row = 0; row < grid.length; row++) {
      for (var col = 0; col < grid[row].length; col++) {
        if (!grid[row][col]) {
          cells.add(CellarCellPosition(row: row + 1, col: col + 1));
        }
      }
    }
    return cells;
  }

  static List<String> validationSummaryLines(List<List<bool>> grid) {
    final rows = grid.length;
    final cols = grid.isEmpty ? 0 : grid.first.length;
    final emptyCount = extractEmptyCells(grid).length;
    final total = rows * cols;
    final activeCount = total - emptyCount;

    return [
      'Dimensions: $rows x $cols',
      'Casiers actifs: $activeCount',
      'Zones vides: $emptyCount',
    ];
  }

  static String selectionSummaryLabel({
    required int rows,
    required int cols,
    required int selectedCount,
  }) {
    return '$rows x $cols - $selectedCount selection';
  }

  static VirtualCellarEntity buildValidatedCellarEntity({
    required List<List<bool>> grid,
    required String effectiveName,
    required VirtualCellarTheme theme,
    required DateTime now,
    VirtualCellarEntity? sourceCellar,
  }) {
    final rows = grid.length;
    final cols = grid.first.length;

    return VirtualCellarEntity(
      id: sourceCellar?.id,
      name: effectiveName,
      rows: rows,
      columns: cols,
      emptyCells: extractEmptyCells(grid),
      theme: theme,
      createdAt: sourceCellar?.createdAt,
      updatedAt: now,
    );
  }

  static List<List<bool>> cloneGrid(List<List<bool>> source) {
    return source.map((row) => List<bool>.from(row)).toList(growable: true);
  }

  static Set<(int, int)> currentSelectionCells({
    required ExpertSelectionState selectionState,
    required int rowCount,
    required int colCount,
  }) {
    switch (selectionState.type) {
      case ExpertSelectionType.cells:
        return Set<(int, int)>.from(selectionState.selectedCells);
      case ExpertSelectionType.row:
        final row = selectionState.selectedRow;
        if (row == null || row < 0 || row >= rowCount) {
          return <(int, int)>{};
        }
        return {for (var col = 0; col < colCount; col++) (row, col)};
      case ExpertSelectionType.column:
        final col = selectionState.selectedCol;
        if (col == null || col < 0 || col >= colCount) {
          return <(int, int)>{};
        }
        return {for (var row = 0; row < rowCount; row++) (row, col)};
      case ExpertSelectionType.none:
        return <(int, int)>{};
    }
  }

  static ExpertSelectionState toggleCellSelection({
    required ExpertSelectionState selectionState,
    required int row,
    required int col,
  }) {
    final selectedCells = selectionState.type == ExpertSelectionType.cells
        ? Set<(int, int)>.from(selectionState.selectedCells)
        : <(int, int)>{};
    final cell = (row, col);
    if (selectedCells.contains(cell)) {
      selectedCells.remove(cell);
    } else {
      selectedCells.add(cell);
    }
    return ExpertSelectionState.cells(selectedCells);
  }

  static ExpertSelectionState startCellSelection({
    required int row,
    required int col,
  }) {
    return ExpertSelectionState.cells({(row, col)});
  }

  static ExpertSelectionState dragSelection({
    required (int, int) anchor,
    required int rowDelta,
    required int colDelta,
    required int rowCount,
    required int colCount,
  }) {
    final targetRow = (anchor.$1 + rowDelta).clamp(0, rowCount - 1);
    final targetCol = (anchor.$2 + colDelta).clamp(0, colCount - 1);

    final minRow = anchor.$1 < targetRow ? anchor.$1 : targetRow;
    final maxRow = anchor.$1 > targetRow ? anchor.$1 : targetRow;
    final minCol = anchor.$2 < targetCol ? anchor.$2 : targetCol;
    final maxCol = anchor.$2 > targetCol ? anchor.$2 : targetCol;

    final selectedCells = <(int, int)>{};
    for (var row = minRow; row <= maxRow; row++) {
      for (var col = minCol; col <= maxCol; col++) {
        selectedCells.add((row, col));
      }
    }

    return ExpertSelectionState.cells(selectedCells);
  }

  static List<List<bool>> applySelectionValue({
    required List<List<bool>> grid,
    required Set<(int, int)> selectedCells,
    required bool active,
  }) {
    final nextGrid = cloneGrid(grid);
    for (final (row, col) in selectedCells) {
      nextGrid[row][col] = active;
    }
    return nextGrid;
  }

  static bool shouldShowRowActions(ExpertSelectionState selectionState) {
    return selectionState.type == ExpertSelectionType.row;
  }

  static bool shouldShowColumnActions(ExpertSelectionState selectionState) {
    return selectionState.type == ExpertSelectionType.column;
  }

  static ({List<List<bool>> grid, ExpertSelectionState selectionState})?
      insertRow({
    required List<List<bool>> grid,
    required ExpertSelectionState selectionState,
    required bool before,
    int maxGridSize = maxSize,
  }) {
    final selectedRow = selectionState.selectedRow;
    if (selectionState.type != ExpertSelectionType.row || selectedRow == null) {
      return null;
    }
    if (grid.length >= maxGridSize) return null;

    final insertAt = before ? selectedRow : selectedRow + 1;
    final nextGrid = cloneGrid(grid);
    nextGrid.insert(insertAt, List<bool>.filled(nextGrid.first.length, true));

    return (
      grid: nextGrid,
      selectionState: ExpertSelectionState.row(insertAt),
    );
  }

  static ({List<List<bool>> grid, ExpertSelectionState selectionState})?
      insertColumn({
    required List<List<bool>> grid,
    required ExpertSelectionState selectionState,
    required bool before,
    int maxGridSize = maxSize,
  }) {
    final selectedCol = selectionState.selectedCol;
    if (selectionState.type != ExpertSelectionType.column ||
        selectedCol == null) {
      return null;
    }
    if (grid.first.length >= maxGridSize) return null;

    final insertAt = before ? selectedCol : selectedCol + 1;
    final nextGrid = cloneGrid(grid);
    for (final row in nextGrid) {
      row.insert(insertAt, true);
    }

    return (
      grid: nextGrid,
      selectionState: ExpertSelectionState.column(insertAt),
    );
  }

  static ({List<List<bool>> grid, ExpertSelectionState selectionState})?
      deleteRow({
    required List<List<bool>> grid,
    required ExpertSelectionState selectionState,
  }) {
    final selectedRow = selectionState.selectedRow;
    if (selectionState.type != ExpertSelectionType.row || selectedRow == null) {
      return null;
    }
    if (grid.length <= 1) return null;

    final nextGrid = cloneGrid(grid)..removeAt(selectedRow);
    final nextSelectedRow = selectedRow.clamp(0, nextGrid.length - 1);
    return (
      grid: nextGrid,
      selectionState: ExpertSelectionState.row(nextSelectedRow),
    );
  }

  static ({List<List<bool>> grid, ExpertSelectionState selectionState})?
      deleteColumn({
    required List<List<bool>> grid,
    required ExpertSelectionState selectionState,
  }) {
    final selectedCol = selectionState.selectedCol;
    if (selectionState.type != ExpertSelectionType.column ||
        selectedCol == null) {
      return null;
    }
    if (grid.first.length <= 1) return null;

    final nextGrid = cloneGrid(grid);
    for (final row in nextGrid) {
      row.removeAt(selectedCol);
    }
    final nextSelectedCol = selectedCol.clamp(0, nextGrid.first.length - 1);
    return (
      grid: nextGrid,
      selectionState: ExpertSelectionState.column(nextSelectedCol),
    );
  }

  static ({List<List<bool>> grid, List<List<List<bool>>> undoStack,
        List<List<List<bool>>> redoStack})
      pushUndoSnapshot({
    required List<List<bool>> grid,
    required List<List<List<bool>>> undoStack,
    required List<List<List<bool>>> redoStack,
    int maxHistory = 50,
  }) {
    final nextUndoStack = List<List<List<bool>>>.from(undoStack)
      ..add(cloneGrid(grid));
    if (nextUndoStack.length > maxHistory) {
      nextUndoStack.removeAt(0);
    }

    return (
      grid: grid,
      undoStack: nextUndoStack,
      redoStack: <List<List<bool>>>[],
    );
  }

  static ({List<List<bool>> grid, List<List<List<bool>>> undoStack,
        List<List<List<bool>>> redoStack})?
      applyUndo({
    required List<List<bool>> grid,
    required List<List<List<bool>>> undoStack,
    required List<List<List<bool>>> redoStack,
  }) {
    if (undoStack.isEmpty) return null;

    final nextUndoStack = List<List<List<bool>>>.from(undoStack);
    final restoredGrid = nextUndoStack.removeLast();
    final nextRedoStack = List<List<List<bool>>>.from(redoStack)
      ..add(cloneGrid(grid));

    return (
      grid: restoredGrid,
      undoStack: nextUndoStack,
      redoStack: nextRedoStack,
    );
  }

  static ({List<List<bool>> grid, List<List<List<bool>>> undoStack,
        List<List<List<bool>>> redoStack})?
      applyRedo({
    required List<List<bool>> grid,
    required List<List<List<bool>>> undoStack,
    required List<List<List<bool>>> redoStack,
  }) {
    if (redoStack.isEmpty) return null;

    final nextRedoStack = List<List<List<bool>>>.from(redoStack);
    final restoredGrid = nextRedoStack.removeLast();
    final nextUndoStack = List<List<List<bool>>>.from(undoStack)
      ..add(cloneGrid(grid));

    return (
      grid: restoredGrid,
      undoStack: nextUndoStack,
      redoStack: nextRedoStack,
    );
  }
}

class ExpertCellarDraftPayload {
  final String name;
  final int rows;
  final int cols;
  final Set<CellarCellPosition> emptyCells;

  const ExpertCellarDraftPayload({
    required this.name,
    required this.rows,
    required this.cols,
    required this.emptyCells,
  });

  List<List<bool>> toGrid() {
    final grid = List<List<bool>>.generate(
      rows,
      (_) => List<bool>.filled(cols, true),
      growable: true,
    );
    for (final cell in emptyCells) {
      final row = cell.row - 1;
      final col = cell.col - 1;
      if (row >= 0 && row < rows && col >= 0 && col < cols) {
        grid[row][col] = false;
      }
    }
    return grid;
  }

  String toJsonString() {
    return jsonEncode({
      'name': name,
      'rows': rows,
      'cols': cols,
      'emptyCells': emptyCells
          .map((cell) => {'row': cell.row, 'col': cell.col})
          .toList(growable: false),
    });
  }

  static ExpertCellarDraftPayload? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final name = (decoded['name'] ?? '').toString();
      final rows = decoded['rows'] is int
          ? decoded['rows'] as int
          : int.tryParse((decoded['rows'] ?? '').toString());
      final cols = decoded['cols'] is int
          ? decoded['cols'] as int
          : int.tryParse((decoded['cols'] ?? '').toString());

      if (rows == null || cols == null || rows < 1 || cols < 1) {
        return null;
      }

      final empty = <CellarCellPosition>{};
      final list = decoded['emptyCells'];
      if (list is List) {
        for (final item in list) {
          if (item is! Map) continue;
          final row = item['row'] is int
              ? item['row'] as int
              : int.tryParse((item['row'] ?? '').toString());
          final col = item['col'] is int
              ? item['col'] as int
              : int.tryParse((item['col'] ?? '').toString());
          if (row == null || col == null || row < 1 || col < 1) continue;
          empty.add(CellarCellPosition(row: row, col: col));
        }
      }

      return ExpertCellarDraftPayload(
        name: name,
        rows: rows,
        cols: cols,
        emptyCells: empty,
      );
    } catch (_) {
      return null;
    }
  }
}