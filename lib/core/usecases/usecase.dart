import 'package:fpdart/fpdart.dart';
import 'package:wine_cellar/core/errors/failures.dart';

/// Base contract for all use cases.
///
/// [ResultType] is the return type on success.
/// [Params] is the input parameter type. Use [NoParams] when none are needed.
///
/// Every use case exposes a single [call] method that returns
/// `Either<Failure, ResultType>`, making error handling explicit at the call site.
abstract class UseCase<ResultType, Params> {
  Future<Either<Failure, ResultType>> call(Params params);
}

/// Marker class when a use case requires no parameters.
class NoParams {
  const NoParams();
}
