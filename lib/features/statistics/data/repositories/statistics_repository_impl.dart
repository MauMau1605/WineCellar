import 'dart:math';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';
import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';
import 'package:wine_cellar/features/statistics/domain/repositories/statistics_repository.dart';

/// Computes cellar statistics from the wine repository.
class StatisticsRepositoryImpl implements StatisticsRepository {
  final WineRepository _wineRepository;

  const StatisticsRepositoryImpl(this._wineRepository);

  @override
  Future<CellarStatistics> getCellarStatistics() async {
    final wines = await _wineRepository.getAllWines();
    if (wines.isEmpty) return CellarStatistics.empty;

    final totalBottles = wines.fold<int>(0, (sum, w) => sum + w.quantity);

    return CellarStatistics(
      overview: _computeOverview(wines, totalBottles),
      colorDistribution: _computeColorDistribution(wines, totalBottles),
      maturityDistribution: _computeMaturityDistribution(wines, totalBottles),
      regionDistribution: _computeRegionDistribution(wines, totalBottles),
      appellationDistribution:
          _computeAppellationDistribution(wines, totalBottles),
      countryDistribution: _computeCountryDistribution(wines, totalBottles),
      vintageDistribution: _computeVintageDistribution(wines),
      grapeDistribution: _computeGrapeDistribution(wines, totalBottles),
      ratingDistribution: _computeRatingDistribution(wines),
      priceStats: _computePriceStats(wines, totalBottles),
      producerDistribution: _computeProducerDistribution(wines, totalBottles),
    );
  }

  // ── Overview ──────────────────────────────────────────────────────────

  OverviewStats _computeOverview(List<WineEntity> wines, int totalBottles) {
    final pricesWithQty = wines
        .where((w) => w.purchasePrice != null)
        .expand((w) => List.filled(w.quantity, w.purchasePrice!));
    final ratingsWithQty = wines
        .where((w) => w.rating != null)
        .expand((w) => List.filled(w.quantity, w.rating!));
    final vintages = wines.where((w) => w.vintage != null).map((w) => w.vintage!);

    double? totalValue;
    double? avgPrice;
    if (pricesWithQty.isNotEmpty) {
      totalValue = pricesWithQty.fold<double>(0, (s, p) => s + p);
      avgPrice = totalValue / pricesWithQty.length;
    }

    double? avgRating;
    if (ratingsWithQty.isNotEmpty) {
      avgRating =
          ratingsWithQty.fold<int>(0, (s, r) => s + r) / ratingsWithQty.length;
    }

    return OverviewStats(
      totalReferences: wines.length,
      totalBottles: totalBottles,
      totalValue: totalValue,
      averagePrice: avgPrice,
      averageRating: avgRating,
      oldestVintage: vintages.isEmpty ? null : vintages.reduce(min),
      newestVintage: vintages.isEmpty ? null : vintages.reduce(max),
    );
  }

  // ── Color ─────────────────────────────────────────────────────────────

  List<ColorStat> _computeColorDistribution(
      List<WineEntity> wines, int totalBottles) {
    final map = <String, _LabeledCount>{};
    for (final w in wines) {
      final key = w.color.name;
      map.putIfAbsent(key, () => _LabeledCount(w.color.label, w.color.emoji));
      map[key]!.count += w.quantity;
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.count.compareTo(a.value.count));
    return sorted
        .map((e) => ColorStat(
              colorName: e.value.label,
              emoji: e.value.emoji,
              bottles: e.value.count,
              percentage: e.value.count / totalBottles * 100,
            ))
        .toList();
  }

  // ── Maturity ──────────────────────────────────────────────────────────

  List<MaturityStat> _computeMaturityDistribution(
      List<WineEntity> wines, int totalBottles) {
    final map = <String, _LabeledCount>{};
    for (final w in wines) {
      final m = w.maturity;
      final key = m.name;
      map.putIfAbsent(key, () => _LabeledCount(m.label, m.emoji));
      map[key]!.count += w.quantity;
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.count.compareTo(a.value.count));
    return sorted
        .map((e) => MaturityStat(
              maturityName: e.value.label,
              emoji: e.value.emoji,
              bottles: e.value.count,
              percentage: e.value.count / totalBottles * 100,
            ))
        .toList();
  }

  // ── Region ────────────────────────────────────────────────────────────

  List<RegionStat> _computeRegionDistribution(
      List<WineEntity> wines, int totalBottles) {
    return _groupByString(
      wines,
      (w) => w.region,
      totalBottles,
      (label, bottles, pct) =>
          RegionStat(region: label, bottles: bottles, percentage: pct),
    );
  }

  // ── Appellation ───────────────────────────────────────────────────────

  List<AppellationStat> _computeAppellationDistribution(
      List<WineEntity> wines, int totalBottles) {
    return _groupByString(
      wines,
      (w) => w.appellation,
      totalBottles,
      (label, bottles, pct) => AppellationStat(
          appellation: label, bottles: bottles, percentage: pct),
    );
  }

  // ── Country ───────────────────────────────────────────────────────────

  List<CountryStat> _computeCountryDistribution(
      List<WineEntity> wines, int totalBottles) {
    return _groupByString(
      wines,
      (w) => w.country,
      totalBottles,
      (label, bottles, pct) =>
          CountryStat(country: label, bottles: bottles, percentage: pct),
    );
  }

  // ── Vintage ───────────────────────────────────────────────────────────

  List<VintageStat> _computeVintageDistribution(List<WineEntity> wines) {
    final map = <int, int>{};
    for (final w in wines) {
      if (w.vintage != null) {
        map[w.vintage!] = (map[w.vintage!] ?? 0) + w.quantity;
      }
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted
        .map((e) => VintageStat(vintage: e.key, bottles: e.value))
        .toList();
  }

  // ── Grape Varieties ───────────────────────────────────────────────────

  List<GrapeVarietyStat> _computeGrapeDistribution(
      List<WineEntity> wines, int totalBottles) {
    final map = <String, int>{};
    for (final w in wines) {
      for (final grape in w.grapeVarieties) {
        final normalized = grape.trim();
        if (normalized.isNotEmpty) {
          map[normalized] = (map[normalized] ?? 0) + w.quantity;
        }
      }
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .map((e) => GrapeVarietyStat(
              grape: e.key,
              bottles: e.value,
              percentage: e.value / totalBottles * 100,
            ))
        .toList();
  }

  // ── Rating ────────────────────────────────────────────────────────────

  List<RatingStat> _computeRatingDistribution(List<WineEntity> wines) {
    final map = <int, int>{};
    for (final w in wines) {
      if (w.rating != null) {
        map[w.rating!] = (map[w.rating!] ?? 0) + w.quantity;
      }
    }
    return List.generate(6, (i) => RatingStat(rating: i, bottles: map[i] ?? 0));
  }

  // ── Price ─────────────────────────────────────────────────────────────

  PriceStats _computePriceStats(List<WineEntity> wines, int totalBottles) {
    final prices = wines
        .where((w) => w.purchasePrice != null)
        .expand((w) => List.filled(w.quantity, w.purchasePrice!))
        .toList();
    if (prices.isEmpty) return PriceStats.empty;

    prices.sort();
    final total = prices.fold<double>(0, (s, p) => s + p);
    final median = prices.length.isOdd
        ? prices[prices.length ~/ 2]
        : (prices[prices.length ~/ 2 - 1] + prices[prices.length ~/ 2]) / 2;

    // Build price ranges
    final ranges = <PriceRangeStat>[];
    final boundaries = [0.0, 5.0, 10.0, 15.0, 20.0, 30.0, 50.0, 100.0, double.infinity];
    final labels = [
      '0 – 5 €',
      '5 – 10 €',
      '10 – 15 €',
      '15 – 20 €',
      '20 – 30 €',
      '30 – 50 €',
      '50 – 100 €',
      '100+ €',
    ];
    for (var i = 0; i < labels.length; i++) {
      final count = prices
          .where((p) => p >= boundaries[i] && p < boundaries[i + 1])
          .length;
      if (count > 0) {
        ranges.add(PriceRangeStat(
          label: labels[i],
          minPrice: boundaries[i],
          maxPrice: boundaries[i + 1],
          bottles: count,
        ));
      }
    }

    return PriceStats(
      minPrice: prices.first,
      maxPrice: prices.last,
      averagePrice: total / prices.length,
      medianPrice: median,
      totalValue: total,
      priceRanges: ranges,
    );
  }

  // ── Producer ──────────────────────────────────────────────────────────

  List<ProducerStat> _computeProducerDistribution(
      List<WineEntity> wines, int totalBottles) {
    return _groupByString(
      wines,
      (w) => w.producer,
      totalBottles,
      (label, bottles, pct) =>
          ProducerStat(producer: label, bottles: bottles, percentage: pct),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  /// Group wines by a nullable string field, sorted by descending count.
  List<T> _groupByString<T>(
    List<WineEntity> wines,
    String? Function(WineEntity) accessor,
    int totalBottles,
    T Function(String label, int bottles, double percentage) factory,
  ) {
    final map = <String, int>{};
    for (final w in wines) {
      final value = accessor(w);
      if (value != null && value.isNotEmpty) {
        map[value] = (map[value] ?? 0) + w.quantity;
      }
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .map((e) => factory(e.key, e.value, e.value / totalBottles * 100))
        .toList();
  }
}

class _LabeledCount {
  final String label;
  final String emoji;
  int count;
  _LabeledCount(this.label, this.emoji) : count = 0;
}
