/// Represents the AI's structured response when analyzing a wine description
class WineAiResponse {
  final String? name;
  final String? appellation;
  final String? producer;
  final String? region;
  final String? country;
  final String? color; // matches WineColor.name
  final int? vintage;
  final List<String> grapeVarieties;
  final int? quantity;
  final double? purchasePrice;
  final int? drinkFromYear;
  final int? drinkUntilYear;
  final String? tastingNotes;
  final List<String> suggestedFoodPairings; // category names
  final String? description; // AI's explanatory text
  final bool needsMoreInfo;
  final String? followUpQuestion;

  /// Fields that were estimated/inferred by the AI (not provided by the user).
  final List<String> estimatedFields;

  /// AI's reasoning for estimated fields (especially drinking window).
  final String? confidenceNotes;

  const WineAiResponse({
    this.name,
    this.appellation,
    this.producer,
    this.region,
    this.country,
    this.color,
    this.vintage,
    this.grapeVarieties = const [],
    this.quantity,
    this.purchasePrice,
    this.drinkFromYear,
    this.drinkUntilYear,
    this.tastingNotes,
    this.suggestedFoodPairings = const [],
    this.description,
    this.needsMoreInfo = false,
    this.followUpQuestion,
    this.estimatedFields = const [],
    this.confidenceNotes,
  });

  factory WineAiResponse.fromJson(Map<String, dynamic> json) {
    return WineAiResponse(
      name: json['name'] as String?,
      appellation: json['appellation'] as String?,
      producer: json['producer'] as String?,
      region: json['region'] as String?,
      country: json['country'] as String?,
      color: json['color'] as String?,
      vintage: json['vintage'] as int?,
      grapeVarieties: (json['grapeVarieties'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      quantity: json['quantity'] as int?,
      purchasePrice: (json['purchasePrice'] as num?)?.toDouble(),
      drinkFromYear: json['drinkFromYear'] as int?,
      drinkUntilYear: json['drinkUntilYear'] as int?,
      tastingNotes: json['tastingNotes'] as String?,
      suggestedFoodPairings: (json['suggestedFoodPairings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      description: json['description'] as String?,
      needsMoreInfo: json['needsMoreInfo'] as bool? ?? false,
      followUpQuestion: json['followUpQuestion'] as String?,
      estimatedFields: (json['estimatedFields'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      confidenceNotes: json['confidenceNotes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'appellation': appellation,
      'producer': producer,
      'region': region,
      'country': country,
      'color': color,
      'vintage': vintage,
      'grapeVarieties': grapeVarieties,
      'quantity': quantity,
      'purchasePrice': purchasePrice,
      'drinkFromYear': drinkFromYear,
      'drinkUntilYear': drinkUntilYear,
      'tastingNotes': tastingNotes,
      'suggestedFoodPairings': suggestedFoodPairings,
      'description': description,
      'needsMoreInfo': needsMoreInfo,
      'followUpQuestion': followUpQuestion,
      'estimatedFields': estimatedFields,
      'confidenceNotes': confidenceNotes,
    };
  }

  /// Check if we have enough info to create a wine entry
  bool get isComplete => name != null && color != null;

  /// Returns the labels of required fields that are null.
  List<String> get missingRequiredFields {
    final missing = <String>[];
    if (name == null) missing.add('Nom');
    if (color == null) missing.add('Couleur');
    return missing;
  }

  /// Returns a copy with non-null fields from [other] overwriting this instance.
  /// Only overwrites fields that are non-null/non-empty in [other].
  WineAiResponse mergeWith(WineAiResponse other) {
    return WineAiResponse(
      name: name,
      appellation: other.appellation ?? appellation,
      producer: other.producer ?? producer,
      region: other.region ?? region,
      country: other.country ?? country,
      color: color,
      vintage: vintage,
      grapeVarieties: other.grapeVarieties.isNotEmpty
          ? other.grapeVarieties
          : grapeVarieties,
      quantity: quantity,
      purchasePrice: purchasePrice,
      drinkFromYear: other.drinkFromYear ?? drinkFromYear,
      drinkUntilYear: other.drinkUntilYear ?? drinkUntilYear,
      tastingNotes: other.tastingNotes ?? tastingNotes,
      suggestedFoodPairings: suggestedFoodPairings,
      description: description,
      needsMoreInfo: needsMoreInfo,
      followUpQuestion: followUpQuestion,
      // Remove completed fields from estimatedFields
      estimatedFields: estimatedFields
          .where((f) => !_fieldWasCompleted(f, other))
          .toList(),
      confidenceNotes: confidenceNotes,
    );
  }

  bool _fieldWasCompleted(String fieldName, WineAiResponse other) {
    return fieldWasCompleted(fieldName, other);
  }

  /// Check if a field was completed by [other].
  static bool fieldWasCompleted(String fieldName, WineAiResponse other) {
    return switch (fieldName) {
      'appellation' => other.appellation != null,
      'region' => other.region != null,
      'country' => other.country != null,
      'producer' => other.producer != null,
      'grapeVarieties' => other.grapeVarieties.isNotEmpty,
      'drinkFromYear' => other.drinkFromYear != null,
      'drinkUntilYear' => other.drinkUntilYear != null,
      'tastingNotes' => other.tastingNotes != null,
      _ => false,
    };
  }
}
