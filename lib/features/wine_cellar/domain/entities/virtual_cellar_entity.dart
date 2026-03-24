import 'dart:convert';

import 'package:wine_cellar/features/wine_cellar/domain/entities/cellar_cell_position.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';

/// Domain entity representing a virtual wine cellar (rack / storage unit).
///
/// A virtual cellar is modelled as a 2-D grid of [rows] × [columns] slots.
/// Each slot may hold one bottle, identified by its [cellarPositionX] (column)
/// and [cellarPositionY] (row) in [WineEntity].
class VirtualCellarEntity {
  final int? id;
  final String name;

  /// Number of rows in the grid.
  final int rows;

  /// Number of columns in the grid.
  final int columns;

  /// Cells that are physically unavailable in the cellar shape.
  /// Coordinates are 1-based.
  final Set<CellarCellPosition> emptyCells;
  final VirtualCellarTheme theme;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VirtualCellarEntity({
    this.id,
    required this.name,
    required this.rows,
    required this.columns,
    this.emptyCells = const <CellarCellPosition>{},
    this.theme = VirtualCellarTheme.classic,
    this.createdAt,
    this.updatedAt,
  });

  /// Total number of cells in the grid, including empty zones.
  int get totalCells => rows * columns;

  /// Number of physically unavailable cells.
  int get emptyCellsCount => emptyCells.length;

  /// Total number of usable slots in the grid.
  int get totalSlots => totalCells - emptyCellsCount;

  bool isCellEmpty({required int oneBasedRow, required int oneBasedCol}) {
    return emptyCells.contains(
      CellarCellPosition(row: oneBasedRow, col: oneBasedCol),
    );
  }

  String? get emptyCellsStorage {
    if (emptyCells.isEmpty) return null;
    final list = emptyCells
        .map((cell) => <String, int>{'row': cell.row, 'col': cell.col})
        .toList(growable: false);
    return jsonEncode(list);
  }

  static Set<CellarCellPosition> parseEmptyCells(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <CellarCellPosition>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <CellarCellPosition>{};
      final result = <CellarCellPosition>{};
      for (final item in decoded) {
        if (item is! Map) continue;
        final row = _asInt(item['row']);
        final col = _asInt(item['col']);
        if (row == null || col == null || row < 1 || col < 1) continue;
        result.add(CellarCellPosition(row: row, col: col));
      }
      return result;
    } catch (_) {
      return <CellarCellPosition>{};
    }
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  VirtualCellarEntity copyWith({
    int? id,
    String? name,
    int? rows,
    int? columns,
    Set<CellarCellPosition>? emptyCells,
    VirtualCellarTheme? theme,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VirtualCellarEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      rows: rows ?? this.rows,
      columns: columns ?? this.columns,
      emptyCells: emptyCells ?? this.emptyCells,
      theme: theme ?? this.theme,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VirtualCellarEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'VirtualCellarEntity(id: $id, name: $name, '
      'rows: $rows, columns: $columns, theme: ${theme.storageValue})';
}
