import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

/// Represents one physical bottle placement in a virtual cellar grid.
class BottlePlacementEntity {
  final int id;
  final int wineId;
  final int cellarId;
  final int positionX;
  final int positionY;
  final DateTime createdAt;
  final WineEntity wine;

  const BottlePlacementEntity({
    required this.id,
    required this.wineId,
    required this.cellarId,
    required this.positionX,
    required this.positionY,
    required this.createdAt,
    required this.wine,
  });
}
