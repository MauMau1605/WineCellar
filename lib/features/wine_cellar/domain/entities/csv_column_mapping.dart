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

  /// All field names in the order expected by the mapping.
  static const List<String> fieldNames = [
    'name',
    'vintage',
    'producer',
    'appellation',
    'quantity',
    'color',
    'region',
    'country',
    'grapeVarieties',
    'purchasePrice',
    'location',
    'notes',
  ];

  /// User-facing labels for each field (French).
  static const Map<String, String> fieldLabels = {
    'name': 'Nom',
    'vintage': 'Millésime',
    'producer': 'Producteur',
    'appellation': 'Appellation',
    'quantity': 'Quantité',
    'color': 'Couleur',
    'region': 'Région',
    'country': 'Pays',
    'grapeVarieties': 'Cépages',
    'purchasePrice': 'Prix achat',
    'location': 'Localisation',
    'notes': 'Notes',
  };

  /// Returns the column number for a given field name, or null.
  int? columnForField(String fieldName) {
    switch (fieldName) {
      case 'name':
        return name;
      case 'vintage':
        return vintage;
      case 'producer':
        return producer;
      case 'appellation':
        return appellation;
      case 'quantity':
        return quantity;
      case 'color':
        return color;
      case 'region':
        return region;
      case 'country':
        return country;
      case 'grapeVarieties':
        return grapeVarieties;
      case 'purchasePrice':
        return purchasePrice;
      case 'location':
        return location;
      case 'notes':
        return notes;
      default:
        return null;
    }
  }

  /// Creates a new mapping from a map of fieldName → column number.
  factory CsvColumnMapping.fromFieldMap(Map<String, int?> map) {
    return CsvColumnMapping(
      name: map['name'],
      vintage: map['vintage'],
      producer: map['producer'],
      appellation: map['appellation'],
      quantity: map['quantity'],
      color: map['color'],
      region: map['region'],
      country: map['country'],
      grapeVarieties: map['grapeVarieties'],
      purchasePrice: map['purchasePrice'],
      location: map['location'],
      notes: map['notes'],
    );
  }

  /// Converts this mapping to a field map.
  Map<String, int?> toFieldMap() {
    return {
      'name': name,
      'vintage': vintage,
      'producer': producer,
      'appellation': appellation,
      'quantity': quantity,
      'color': color,
      'region': region,
      'country': country,
      'grapeVarieties': grapeVarieties,
      'purchasePrice': purchasePrice,
      'location': location,
      'notes': notes,
    };
  }
}
