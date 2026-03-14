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

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VirtualCellarEntity({
    this.id,
    required this.name,
    required this.rows,
    required this.columns,
    this.createdAt,
    this.updatedAt,
  });

  /// Total number of slots in the grid.
  int get totalSlots => rows * columns;

  VirtualCellarEntity copyWith({
    int? id,
    String? name,
    int? rows,
    int? columns,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VirtualCellarEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      rows: rows ?? this.rows,
      columns: columns ?? this.columns,
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
  String toString() => 'VirtualCellarEntity(id: $id, name: $name, '
      'rows: $rows, columns: $columns)';
}
