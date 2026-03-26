enum VirtualCellarTheme {
  classic,
  premiumCave,
  stoneCave,
  garageIndustrial;

  String get storageValue => name;

  String get label {
    switch (this) {
      case VirtualCellarTheme.classic:
        return 'Cave classique';
      case VirtualCellarTheme.premiumCave:
        return 'Cave premium';
      case VirtualCellarTheme.stoneCave:
        return 'Cave en pierre';
      case VirtualCellarTheme.garageIndustrial:
        return 'Garage industriel';
    }
  }

  static VirtualCellarTheme fromStorage(String? raw) {
    return VirtualCellarTheme.values.firstWhere(
      (theme) => theme.storageValue == raw,
      orElse: () => VirtualCellarTheme.classic,
    );
  }
}
