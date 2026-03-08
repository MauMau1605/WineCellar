/// User-provided mapping between CSV columns and wine fields.
///
/// Each column number is 1-based in order to match what users see in table
/// editors (A=1, B=2, ...). A null value means the information is not present
/// in the CSV file.
class CsvColumnMapping {
  final int? name;
  final int? vintage;
  final int? producer;
  final int? appellation;
  final int? quantity;
  final int? color;
  final int? region;
  final int? country;
  final int? grapeVarieties;
  final int? purchasePrice;
  final int? location;
  final int? notes;

  const CsvColumnMapping({
    this.name,
    this.vintage,
    this.producer,
    this.appellation,
    this.quantity,
    this.color,
    this.region,
    this.country,
    this.grapeVarieties,
    this.purchasePrice,
    this.location,
    this.notes,
  });

  CsvColumnMapping copyWith({
    int? name,
    int? vintage,
    int? producer,
    int? appellation,
    int? quantity,
    int? color,
    int? region,
    int? country,
    int? grapeVarieties,
    int? purchasePrice,
    int? location,
    int? notes,
  }) {
    return CsvColumnMapping(
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

  bool get hasMinimumFields => name != null;
}
