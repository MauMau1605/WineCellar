/// Base class for typed failures in the application.
/// Used with [Either<Failure, T>] from fpdart for explicit error handling.
sealed class Failure {
  final String message;
  final Object? cause;

  const Failure(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';
}

/// Failure linked to a server / remote API call
class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure(super.message, {super.cause, this.statusCode});
}

/// Failure linked to local database / cache operations
class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.cause});
}

/// Failure linked to AI service interactions
class AiFailure extends Failure {
  final String? provider;

  const AiFailure(super.message, {super.cause, this.provider});
}

/// Failure linked to invalid input / validation
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.cause});
}

/// Failure for features not yet available or missing configuration
class ConfigurationFailure extends Failure {
  const ConfigurationFailure(super.message, {super.cause});
}
