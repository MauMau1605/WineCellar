/// 1-based cellar cell position.
class CellarCellPosition {
  final int row;
  final int col;

  const CellarCellPosition({required this.row, required this.col});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellarCellPosition && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);
}
