import 'dart:convert';
import 'package:wine_cellar/core/enums.dart';

/// Domain entity representing a wine in the cellar
class WineEntity {
  final int? id;
  final String name;
  final String? appellation;
  final String? producer;
  final String? region;
  final String country;
  final WineColor color;
  final int? vintage;
  final List<String> grapeVarieties;
  final int quantity;
  final double? purchasePrice;
  final DateTime? purchaseDate;
  final int? drinkFromYear;
  final int? drinkUntilYear;
  final String? tastingNotes;
  final int? rating;
  final String? photoPath;
  final String? aiDescription;
  final String? location;
  final String? notes;
  final List<int> foodCategoryIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WineEntity({
    this.id,
    required this.name,
    this.appellation,
    this.producer,
    this.region,
    this.country = 'France',
    required this.color,
    this.vintage,
    this.grapeVarieties = const [],
    this.quantity = 1,
    this.purchasePrice,
    this.purchaseDate,
    this.drinkFromYear,
    this.drinkUntilYear,
    this.tastingNotes,
    this.rating,
    this.photoPath,
    this.aiDescription,
    this.location,
    this.notes,
    this.foodCategoryIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// Get the maturity status based on current year
  WineMaturity get maturity {
    if (drinkFromYear == null && drinkUntilYear == null) {
      return WineMaturity.unknown;
    }

    final currentYear = DateTime.now().year;

    if (drinkFromYear != null && currentYear < drinkFromYear!) {
      return WineMaturity.tooYoung;
    }
    if (drinkUntilYear != null && currentYear > drinkUntilYear!) {
      return WineMaturity.pastPeak;
    }
    // If we're in the last 20% of the drinking window, it's at peak
    if (drinkFromYear != null && drinkUntilYear != null) {
      final windowSize = drinkUntilYear! - drinkFromYear!;
      final peakStart = drinkUntilYear! - (windowSize * 0.3).round();
      if (currentYear >= peakStart) {
        return WineMaturity.peak;
      }
    }
    return WineMaturity.ready;
  }

  /// Full display name with vintage
  String get displayName {
    if (vintage != null) {
      return '$name $vintage';
    }
    return name;
  }

  /// Create a copy with modifications
  WineEntity copyWith({
    int? id,
    String? name,
    String? appellation,
    String? producer,
    String? region,
    String? country,
    WineColor? color,
    int? vintage,
    List<String>? grapeVarieties,
    int? quantity,
    double? purchasePrice,
    DateTime? purchaseDate,
    int? drinkFromYear,
    int? drinkUntilYear,
    String? tastingNotes,
    int? rating,
    String? photoPath,
    String? aiDescription,
    String? location,
    String? notes,
    List<int>? foodCategoryIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WineEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      appellation: appellation ?? this.appellation,
      producer: producer ?? this.producer,
      region: region ?? this.region,
      country: country ?? this.country,
      color: color ?? this.color,
      vintage: vintage ?? this.vintage,
      grapeVarieties: grapeVarieties ?? this.grapeVarieties,
      quantity: quantity ?? this.quantity,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      drinkFromYear: drinkFromYear ?? this.drinkFromYear,
      drinkUntilYear: drinkUntilYear ?? this.drinkUntilYear,
      tastingNotes: tastingNotes ?? this.tastingNotes,
      rating: rating ?? this.rating,
      photoPath: photoPath ?? this.photoPath,
      aiDescription: aiDescription ?? this.aiDescription,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      foodCategoryIds: foodCategoryIds ?? this.foodCategoryIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to JSON map for export
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'appellation': appellation,
      'producer': producer,
      'region': region,
      'country': country,
      'color': color.name,
      'vintage': vintage,
      'grapeVarieties': grapeVarieties,
      'quantity': quantity,
      'purchasePrice': purchasePrice,
      'purchaseDate': purchaseDate?.toIso8601String(),
      'drinkFromYear': drinkFromYear,
      'drinkUntilYear': drinkUntilYear,
      'tastingNotes': tastingNotes,
      'rating': rating,
      'aiDescription': aiDescription,
      'location': location,
      'notes': notes,
      'foodCategoryIds': foodCategoryIds,
    };
  }

  /// Create from JSON map (import)
  factory WineEntity.fromJson(Map<String, dynamic> json) {
    return WineEntity(
      id: json['id'] as int?,
      name: json['name'] as String,
      appellation: json['appellation'] as String?,
      producer: json['producer'] as String?,
      region: json['region'] as String?,
      country: json['country'] as String? ?? 'France',
      color: WineColor.values.firstWhere(
        (c) => c.name == json['color'],
        orElse: () => WineColor.red,
      ),
      vintage: json['vintage'] as int?,
      grapeVarieties: (json['grapeVarieties'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      quantity: json['quantity'] as int? ?? 1,
      purchasePrice: (json['purchasePrice'] as num?)?.toDouble(),
      purchaseDate: json['purchaseDate'] != null
          ? DateTime.tryParse(json['purchaseDate'] as String)
          : null,
      drinkFromYear: json['drinkFromYear'] as int?,
      drinkUntilYear: json['drinkUntilYear'] as int?,
      tastingNotes: json['tastingNotes'] as String?,
      rating: json['rating'] as int?,
      aiDescription: json['aiDescription'] as String?,
      location: json['location'] as String?,
      notes: json['notes'] as String?,
      foodCategoryIds: (json['foodCategoryIds'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }

  /// Serialize grapeVarieties list to JSON string for DB storage
  String get grapeVarietiesJson => jsonEncode(grapeVarieties);

  /// Deserialize grapeVarieties from JSON string
  static List<String> parseGrapeVarieties(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      return (jsonDecode(json) as List<dynamic>)
          .map((e) => e as String)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
