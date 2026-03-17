import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/providers/bottle_move_state_provider.dart';

void main() {
  group('BottleMoveStateNotifier', () {
    test('startMoving enters movement mode and selects the anchor bottle', () {
      final notifier = BottleMoveStateNotifier(42);

      notifier.startMoving(7);

      expect(notifier.state.isMovementMode, isTrue);
      expect(notifier.state.isDragModeEnabled, isFalse);
      expect(notifier.state.selectedPlacementIds, {7});
    });

    test('enableDragMode only works when selection exists', () {
      final notifier = BottleMoveStateNotifier(42);

      notifier.enableDragMode();
      expect(notifier.state.isDragModeEnabled, isFalse);

      notifier.startMoving(10);
      notifier.enableDragMode();
      expect(notifier.state.isDragModeEnabled, isTrue);
    });

    test('toggleMovementMode clears selection when exiting movement mode', () {
      final notifier = BottleMoveStateNotifier(42);

      notifier.startMoving(3);
      notifier.enableDragMode();
      notifier.toggleMovementMode();

      expect(notifier.state.isMovementMode, isFalse);
      expect(notifier.state.isDragModeEnabled, isFalse);
      expect(notifier.state.selectedPlacementIds, isEmpty);
    });
  });
}
