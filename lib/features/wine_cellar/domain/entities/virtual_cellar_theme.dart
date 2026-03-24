enum VirtualCellarTheme {
  classic,
  wineFridge,
  premiumCave;

  String get storageValue => name;

  String get label {
    switch (this) {
      case VirtualCellarTheme.classic:
        return 'Cave classique';
      case VirtualCellarTheme.wineFridge:
        return 'Frigo a vin';
      case VirtualCellarTheme.premiumCave:
        return 'Cave premium';
    }
  }

  static VirtualCellarTheme fromStorage(String? raw) {
    return VirtualCellarTheme.values.firstWhere(
      (theme) => theme.storageValue == raw,
      orElse: () => VirtualCellarTheme.classic,
    );
  }
}
