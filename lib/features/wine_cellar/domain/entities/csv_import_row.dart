/// Parsed row extracted from a CSV import file.
///
/// Fields can be null when the source CSV does not provide them.
class CsvImportRow {
  final int sourceRowNumber;
  final String? name;
  final int? vintage;
  final String? producer;
  final String? appellation;
  final int? quantity;
  final String? color;
  final String? region;
  final String? country;
  final List<String> grapeVarieties;
  final double? purchasePrice;
  final String? location;
  final String? notes;

  const CsvImportRow({
    required this.sourceRowNumber,
    this.name,
    this.vintage,
    this.producer,
    this.appellation,
    this.quantity,
    this.color,
    this.region,
    this.country,
    this.grapeVarieties = const [],
    this.purchasePrice,
    this.location,
    this.notes,
  });

  CsvImportRow copyWith({
    int? sourceRowNumber,
    String? name,
    int? vintage,
    String? producer,
    String? appellation,
    int? quantity,
    String? color,
    String? region,
    String? country,
    List<String>? grapeVarieties,
    double? purchasePrice,
    String? location,
    String? notes,
  }) {
    return CsvImportRow(
      sourceRowNumber: sourceRowNumber ?? this.sourceRowNumber,
      name: name ?? this.name,
      vintage: vintage ?? this.vintage,
      producer: producer ?? this.producer,
      appellation: appellation ?? this.appellation,
      quantity: quantity ?? this.quantity,
      color: color ?? this.color,
      region: region ?? this.region,
      country: country ?? this.country,
      grapeVarieties: grapeVarieties ?? this.grapeVarieties,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      location: location ?? this.location,
      notes: notes ?? this.notes,
    );
  }

  bool get hasName => (name ?? '').trim().isNotEmpty;
}
