/// Status du résultat d'une recherche Vivino.
enum VivinoSourceStatus {
  /// Vin trouvé et avis récupérés avec succès.
  found,

  /// Vin trouvé sur Vivino mais aucun avis disponible.
  foundNoReviews,

  /// Aucun vin correspondant trouvé sur Vivino.
  notFound,

  /// La requête Vivino a échoué (réseau, parsing, blocage…).
  unavailable,
}

/// Un avis individuel extrait de Vivino.
class VivinoReview {
  final double rating;
  final String? note;
  final String? language;
  final String? createdAt;

  const VivinoReview({
    required this.rating,
    this.note,
    this.language,
    this.createdAt,
  });
}

/// Résultat agrégé d'une recherche Vivino (vin + avis).
class VivinoSearchResult {
  final VivinoSourceStatus status;
  final int? wineId;
  final String? wineName;
  final String? winery;
  final String? region;
  final String? country;
  final int? vintage;
  final double? ratingsAverage;
  final int? ratingsCount;
  final List<VivinoReview> reviews;
  final String? wineUrl;

  /// Année de début de la fenêtre de dégustation recommandée (peut être null).
  final int? beginConsume;

  /// Année de fin de la fenêtre de dégustation recommandée (peut être null).
  final int? endConsume;

  const VivinoSearchResult({
    required this.status,
    this.wineId,
    this.wineName,
    this.winery,
    this.region,
    this.country,
    this.vintage,
    this.ratingsAverage,
    this.ratingsCount,
    this.reviews = const [],
    this.wineUrl,
    this.beginConsume,
    this.endConsume,
  });

  factory VivinoSearchResult.notFound() =>
      const VivinoSearchResult(status: VivinoSourceStatus.notFound);

  factory VivinoSearchResult.unavailable() =>
      const VivinoSearchResult(status: VivinoSourceStatus.unavailable);
}
