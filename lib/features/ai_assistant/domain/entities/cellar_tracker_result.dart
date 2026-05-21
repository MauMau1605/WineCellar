/// Statut du résultat d'une recherche CellarTracker.
enum CellarTrackerSourceStatus {
  /// Vin trouvé et données récupérées avec succès.
  found,

  /// Aucun vin correspondant trouvé sur CellarTracker.
  notFound,

  /// Identifiants CellarTracker non configurés — recherche ignorée silencieusement.
  unconfigured,

  /// La requête CellarTracker a échoué (réseau, parsing, blocage…).
  unavailable,
}

/// Une note individuelle extraite de CellarTracker.
class CellarTrackerNote {
  /// Score de l'avis (0–100). Peut être null si absent.
  final double? rating;

  /// Texte de l'avis.
  final String? note;

  /// Auteur de l'avis.
  final String? author;

  const CellarTrackerNote({this.rating, this.note, this.author});
}

/// Résultat agrégé d'une recherche CellarTracker (vin + avis communauté).
class CellarTrackerResult {
  final CellarTrackerSourceStatus status;
  final String? wineName;
  final int? vintage;

  /// Score moyen communautaire CellarTracker (0–100).
  final double? communityScore;

  /// Nombre de notes communautaires.
  final int? communityCount;

  /// Année de début de la fenêtre de dégustation recommandée.
  final int? beginConsume;

  /// Année de fin de la fenêtre de dégustation recommandée.
  final int? endConsume;

  /// Premières notes individuelles de la communauté.
  final List<CellarTrackerNote> notes;

  const CellarTrackerResult({
    required this.status,
    this.wineName,
    this.vintage,
    this.communityScore,
    this.communityCount,
    this.beginConsume,
    this.endConsume,
    this.notes = const [],
  });

  factory CellarTrackerResult.unconfigured() =>
      const CellarTrackerResult(
        status: CellarTrackerSourceStatus.unconfigured,
      );

  factory CellarTrackerResult.notFound() =>
      const CellarTrackerResult(
        status: CellarTrackerSourceStatus.notFound,
      );

  factory CellarTrackerResult.unavailable() =>
      const CellarTrackerResult(
        status: CellarTrackerSourceStatus.unavailable,
      );
}
