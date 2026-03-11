class FoodPairingPreset {
  final String name;
  final String icon;
  final int sortOrder;

  const FoodPairingPreset({
    required this.name,
    required this.icon,
    required this.sortOrder,
  });
}

const List<FoodPairingPreset> defaultFoodPairingCatalog = [
  FoodPairingPreset(name: 'Viande rouge', icon: '🥩', sortOrder: 1),
  FoodPairingPreset(name: 'Viande blanche', icon: '🍗', sortOrder: 2),
  FoodPairingPreset(name: 'Volaille', icon: '🐔', sortOrder: 3),
  FoodPairingPreset(name: 'Gibier', icon: '🦌', sortOrder: 4),
  FoodPairingPreset(name: 'Poisson', icon: '🐟', sortOrder: 5),
  FoodPairingPreset(name: 'Fruits de mer', icon: '🦐', sortOrder: 6),
  FoodPairingPreset(name: 'Fromage', icon: '🧀', sortOrder: 7),
  FoodPairingPreset(name: 'Charcuterie', icon: '🥓', sortOrder: 8),
  FoodPairingPreset(name: 'Pâtes / Risotto', icon: '🍝', sortOrder: 9),
  FoodPairingPreset(name: 'Pizza', icon: '🍕', sortOrder: 10),
  FoodPairingPreset(name: 'Salade', icon: '🥗', sortOrder: 11),
  FoodPairingPreset(name: 'Soupe', icon: '🍲', sortOrder: 12),
  FoodPairingPreset(name: 'Barbecue / Grillades', icon: '🔥', sortOrder: 13),
  FoodPairingPreset(name: 'Cuisine asiatique', icon: '🥢', sortOrder: 14),
  FoodPairingPreset(name: 'Cuisine épicée', icon: '🌶️', sortOrder: 15),
  FoodPairingPreset(name: 'Dessert chocolat', icon: '🍫', sortOrder: 16),
  FoodPairingPreset(name: 'Dessert fruité', icon: '🍓', sortOrder: 17),
  FoodPairingPreset(name: 'Apéritif', icon: '🥂', sortOrder: 18),
];
