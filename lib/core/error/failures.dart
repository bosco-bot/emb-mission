import 'package:equatable/equatable.dart';

/// Classe de base pour les échecs dans l'application
abstract class Failure extends Equatable {
  const Failure();

  @override
  List<Object> get props => [];
}

/// Échec lié au serveur
class ServerFailure extends Failure {
  final String message;
  
  const ServerFailure({this.message = 'Erreur de serveur'});
  
  @override
  List<Object> get props => [message];
}

/// Échec lié à la connexion
class ConnectionFailure extends Failure {
  final String message;
  
  const ConnectionFailure({this.message = 'Erreur de connexion'});
  
  @override
  List<Object> get props => [message];
}

/// Échec lié au cache
class CacheFailure extends Failure {
  final String message;
  
  const CacheFailure({this.message = 'Erreur de cache'});
  
  @override
  List<Object> get props => [message];
}

/// Échec lié à une opération non autorisée
class UnauthorizedFailure extends Failure {
  final String message;
  
  const UnauthorizedFailure({this.message = 'Non autorisé'});
  
  @override
  List<Object> get props => [message];
}

/// Échec lié à une validation
class ValidationFailure extends Failure {
  final String message;
  
  const ValidationFailure({this.message = 'Erreur de validation'});
  
  @override
  List<Object> get props => [message];
}
