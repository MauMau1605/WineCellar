import 'package:fpdart/fpdart.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';

/// Parameters for [UpdateWineQuantityUseCase].
class UpdateQuantityParams {
  final int wineId;
  final int newQuantity;

  const UpdateQuantityParams({
    required this.wineId,
    required this.newQuantity,
  });
}

/// Possible outcomes when the new quantity reaches zero.
enum ZeroQuantityAction { keep, delete }

/// Update the quantity of a wine bottle.
///
/// When the quantity drops to 0 or below, the caller must provide a
/// [ZeroQuantityAction] via [callWithAction] to decide whether to keep
/// the entry at 0 or delete it entirely.
class UpdateWineQuantityUseCase
    implements UseCase<void, UpdateQuantityParams> {
  final WineRepository _repository;

  const UpdateWineQuantityUseCase(this._repository);

  /// Standard call — clamps quantity to 0 minimum and persists it.
  @override
  Future<Either<Failure, void>> call(UpdateQuantityParams params) async {
    try {
      final qty = params.newQuantity < 0 ? 0 : params.newQuantity;
      await _repository.updateQuantity(params.wineId, qty);
      return const Right(null);
    } catch (e) {
      return Left(
        CacheFailure('Impossible de mettre à jour la quantité.', cause: e),
      );
    }
  }

  /// Extended call that handles the zero-quantity business rule.
  Future<Either<Failure, void>> callWithAction(
    UpdateQuantityParams params,
    ZeroQuantityAction action,
  ) async {
    try {
      if (params.newQuantity <= 0 && action == ZeroQuantityAction.delete) {
        await _repository.deleteWine(params.wineId);
        return const Right(null);
      }

      final qty = params.newQuantity < 0 ? 0 : params.newQuantity;
      await _repository.updateQuantity(params.wineId, qty);
      return const Right(null);
    } catch (e) {
      return Left(
        CacheFailure('Impossible de mettre à jour la quantité.', cause: e),
      );
    }
  }
}
