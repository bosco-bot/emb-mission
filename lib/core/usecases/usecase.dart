import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../error/failures.dart';

/// Interface générique pour tous les cas d'utilisation
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

/// Classe pour les cas d'utilisation sans paramètres
class NoParams extends Equatable {
  @override
  List<Object> get props => [];
}
