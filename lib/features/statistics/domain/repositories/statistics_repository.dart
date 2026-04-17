import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';

/// Abstract repository for computing cellar statistics.
abstract class StatisticsRepository {
  /// Compute statistics from all wines currently in the cellar.
  Future<CellarStatistics> getCellarStatistics();
}
