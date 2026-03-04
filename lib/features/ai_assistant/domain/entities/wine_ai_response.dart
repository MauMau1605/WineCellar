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
    };
  }

  /// Check if we have enough info to create a wine entry
  bool get isComplete => name != null && color != null;
}
