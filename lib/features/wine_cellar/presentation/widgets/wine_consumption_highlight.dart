import 'package:flutter/material.dart';

import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

enum WineConsumptionHighlight {
  none,
  lastConsumptionYear,
  pastOptimalWindow,
}

WineConsumptionHighlight computeWineConsumptionHighlight(
  WineEntity wine, {
  required bool highlightLastConsumptionYear,
  required bool highlightPastOptimalWindow,
  DateTime? now,
}) {
  final until = wine.drinkUntilYear;
  if (until == null) return WineConsumptionHighlight.none;

  final currentYear = (now ?? DateTime.now()).year;

  if (highlightPastOptimalWindow && currentYear > until) {
    return WineConsumptionHighlight.pastOptimalWindow;
  }

  if (highlightLastConsumptionYear && currentYear == until) {
    return WineConsumptionHighlight.lastConsumptionYear;
  }

  return WineConsumptionHighlight.none;
}

Color colorForConsumptionHighlight(WineConsumptionHighlight highlight) {
  switch (highlight) {
    case WineConsumptionHighlight.none:
      return Colors.transparent;
    case WineConsumptionHighlight.lastConsumptionYear:
      return const Color(0xFFD18A00);
    case WineConsumptionHighlight.pastOptimalWindow:
      return const Color(0xFF8E2D21);
  }
}

String? labelForConsumptionHighlight(WineConsumptionHighlight highlight) {
  switch (highlight) {
    case WineConsumptionHighlight.none:
      return null;
    case WineConsumptionHighlight.lastConsumptionYear:
      return 'A boire cette annee';
    case WineConsumptionHighlight.pastOptimalWindow:
      return 'Fenetre depassee';
  }
}
