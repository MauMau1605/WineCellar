import 'package:fpdart/fpdart.dart';

import 'package:wine_cellar/core/errors/failures.dart';
import '../repositories/virtual_cellar_repository.dart';

class DeleteVirtualCellarUseCase {
  final VirtualCellarRepository _repository;

  DeleteVirtualCellarUseCase(this._repository);

  Future<Either<Failure, Unit>> call(int cellarId) {
    return _repository.delete(cellarId);
  }
}
