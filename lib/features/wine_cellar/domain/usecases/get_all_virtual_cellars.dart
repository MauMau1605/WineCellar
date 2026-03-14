import 'package:fpdart/fpdart.dart';

import 'package:wine_cellar/core/errors/failures.dart';
import '../entities/virtual_cellar_entity.dart';
import '../repositories/virtual_cellar_repository.dart';

class GetAllVirtualCellarsUseCase {
  final VirtualCellarRepository _repository;

  GetAllVirtualCellarsUseCase(this._repository);

  Future<Either<Failure, List<VirtualCellarEntity>>> call() {
    return _repository.getAll();
  }

  Stream<List<VirtualCellarEntity>> watch() {
    return _repository.watchAll();
  }
}
