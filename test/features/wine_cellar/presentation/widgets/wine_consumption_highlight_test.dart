import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/wine_consumption_highlight.dart';

void main() {
  WineEntity buildWine({int? drinkUntilYear}) {
    return WineEntity(
      name: 'Test Wine',
      color: WineColor.red,
      drinkUntilYear: drinkUntilYear,
    );
  }

  group('computeWineConsumptionHighlight', () {
    test('returns none when drinkUntilYear is missing', () {
      final wine = buildWine();

      final result = computeWineConsumptionHighlight(
        wine,
        highlightLastConsumptionYear: true,
        highlightPastOptimalWindow: true,
        now: DateTime(2026, 1, 1),
      );

      expect(result, WineConsumptionHighlight.none);
    });

    test('returns lastConsumptionYear when current year matches and toggle is on', () {
      final wine = buildWine(drinkUntilYear: 2026);

      final result = computeWineConsumptionHighlight(
        wine,
        highlightLastConsumptionYear: true,
        highlightPastOptimalWindow: true,
        now: DateTime(2026, 6, 10),
      );

      expect(result, WineConsumptionHighlight.lastConsumptionYear);
    });

    test('returns none on last year if last-year toggle is off', () {
      final wine = buildWine(drinkUntilYear: 2026);

      final result = computeWineConsumptionHighlight(
        wine,
        highlightLastConsumptionYear: false,
        highlightPastOptimalWindow: true,
        now: DateTime(2026, 6, 10),
      );

      expect(result, WineConsumptionHighlight.none);
    });

    test('returns pastOptimalWindow when year is past and toggle is on', () {
      final wine = buildWine(drinkUntilYear: 2025);

      final result = computeWineConsumptionHighlight(
        wine,
        highlightLastConsumptionYear: true,
        highlightPastOptimalWindow: true,
        now: DateTime(2026, 2, 3),
      );

      expect(result, WineConsumptionHighlight.pastOptimalWindow);
    });

    test('returns none when past-optimal toggle is off', () {
      final wine = buildWine(drinkUntilYear: 2025);

      final result = computeWineConsumptionHighlight(
        wine,
        highlightLastConsumptionYear: true,
        highlightPastOptimalWindow: false,
        now: DateTime(2026, 2, 3),
      );

      expect(result, WineConsumptionHighlight.none);
    });
  });
}
