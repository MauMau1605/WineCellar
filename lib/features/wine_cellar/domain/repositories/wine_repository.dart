import '../entities/wine_entity.dart';
import '../entities/wine_filter.dart';

/// Abstract repository interface for wine operations
/// Concrete implementation in data layer uses Drift
abstract class WineRepository {
  /// Watch all wines (reactive stream)
  Stream<List<WineEntity>> watchAllWines();

  /// Watch wines with a specific filter
  Stream<List<WineEntity>> watchFilteredWines(WineFilter filter);

  /// Get a single wine by ID with its food pairings
  Future<WineEntity?> getWineById(int id);

  /// Add a new wine to the cellar
  Future<int> addWine(WineEntity wine);

  /// Update an existing wine
  Future<void> updateWine(WineEntity wine);

  /// Delete a wine by ID
  Future<void> deleteWine(int id);

  /// Update the quantity of a wine
  Future<void> updateQuantity(int wineId, int quantity);

  /// Get all wines as a list (one-shot, non-reactive)
  Future<List<WineEntity>> getAllWines();

  /// Get total wine count
  Future<int> getWineCount();

  /// Get total bottle count
  Future<int> getTotalBottles();

  /// Export all wines as JSON string
  Future<String> exportToJson();

  /// Export all wines as CSV string
  Future<String> exportToCsv();

  /// Import wines from a JSON string
  Future<int> importFromJson(String jsonString);
}
