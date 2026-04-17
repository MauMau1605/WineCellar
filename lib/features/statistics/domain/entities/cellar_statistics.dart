/// Domain entities for cellar statistics.
///
/// All entities are immutable data classes computed from the wine collection.
/// Quantities are expressed in bottles (wine.quantity), not unique references.

/// Top-level aggregation of all cellar statistics.
class CellarStatistics {
  final OverviewStats overview;
  final List<ColorStat> colorDistribution;
  final List<MaturityStat> maturityDistribution;
  final List<RegionStat> regionDistribution;
  final List<AppellationStat> appellationDistribution;
  final List<CountryStat> countryDistribution;
  final List<VintageStat> vintageDistribution;
  final List<GrapeVarietyStat> grapeDistribution;
  final List<RatingStat> ratingDistribution;
  final PriceStats priceStats;
  final List<ProducerStat> producerDistribution;

  const CellarStatistics({
    required this.overview,
    required this.colorDistribution,
    required this.maturityDistribution,
    required this.regionDistribution,
    required this.appellationDistribution,
    required this.countryDistribution,
    required this.vintageDistribution,
    required this.grapeDistribution,
    required this.ratingDistribution,
    required this.priceStats,
    required this.producerDistribution,
  });

  /// Empty statistics when the cellar has no wines.
  static const empty = CellarStatistics(
    overview: OverviewStats.empty,
    colorDistribution: [],
    maturityDistribution: [],
    regionDistribution: [],
    appellationDistribution: [],
    countryDistribution: [],
    vintageDistribution: [],
    grapeDistribution: [],
    ratingDistribution: [],
    priceStats: PriceStats.empty,
    producerDistribution: [],
  );

  bool get isEmpty => overview.totalBottles == 0;
}

/// Key performance indicators for the cellar.
class OverviewStats {
  final int totalReferences;
  final int totalBottles;
  final double? totalValue;
  final double? averagePrice;
  final double? averageRating;
  final int? oldestVintage;
  final int? newestVintage;

  const OverviewStats({
    required this.totalReferences,
    required this.totalBottles,
    this.totalValue,
    this.averagePrice,
    this.averageRating,
    this.oldestVintage,
    this.newestVintage,
  });

  static const empty = OverviewStats(
    totalReferences: 0,
    totalBottles: 0,
  );
}

/// Distribution entry: a label with its bottle count.
class ColorStat {
  final String colorName;
  final String emoji;
  final int bottles;
  final double percentage;

  const ColorStat({
    required this.colorName,
    required this.emoji,
    required this.bottles,
    required this.percentage,
  });
}

class MaturityStat {
  final String maturityName;
  final String emoji;
  final int bottles;
  final double percentage;

  const MaturityStat({
    required this.maturityName,
    required this.emoji,
    required this.bottles,
    required this.percentage,
  });
}

class RegionStat {
  final String region;
  final int bottles;
  final double percentage;

  const RegionStat({
    required this.region,
    required this.bottles,
    required this.percentage,
  });
}

class AppellationStat {
  final String appellation;
  final int bottles;
  final double percentage;

  const AppellationStat({
    required this.appellation,
    required this.bottles,
    required this.percentage,
  });
}

class CountryStat {
  final String country;
  final int bottles;
  final double percentage;

  const CountryStat({
    required this.country,
    required this.bottles,
    required this.percentage,
  });
}

class VintageStat {
  final int vintage;
  final int bottles;

  const VintageStat({
    required this.vintage,
    required this.bottles,
  });
}

class GrapeVarietyStat {
  final String grape;
  final int bottles;
  final double percentage;

  const GrapeVarietyStat({
    required this.grape,
    required this.bottles,
    required this.percentage,
  });
}

class RatingStat {
  final int rating;
  final int bottles;

  const RatingStat({
    required this.rating,
    required this.bottles,
  });
}

class PriceStats {
  final double? minPrice;
  final double? maxPrice;
  final double? averagePrice;
  final double? medianPrice;
  final double? totalValue;
  final List<PriceRangeStat> priceRanges;

  const PriceStats({
    this.minPrice,
    this.maxPrice,
    this.averagePrice,
    this.medianPrice,
    this.totalValue,
    this.priceRanges = const [],
  });

  static const empty = PriceStats();

  bool get hasData => minPrice != null;
}

class PriceRangeStat {
  final String label;
  final double minPrice;
  final double maxPrice;
  final int bottles;

  const PriceRangeStat({
    required this.label,
    required this.minPrice,
    required this.maxPrice,
    required this.bottles,
  });
}

class ProducerStat {
  final String producer;
  final int bottles;
  final double percentage;

  const ProducerStat({
    required this.producer,
    required this.bottles,
    required this.percentage,
  });
}
