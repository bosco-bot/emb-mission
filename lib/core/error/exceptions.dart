/// Exception lancée lorsqu'il y a une erreur de serveur
class ServerException implements Exception {}

/// Exception lancée lorsqu'il y a une erreur de cache
class CacheException implements Exception {}

/// Exception lancée lorsqu'il y a une erreur de connexion
class ConnectionException implements Exception {}

/// Exception lancée lorsqu'une opération n'est pas autorisée
class UnauthorizedException implements Exception {}

/// Exception lancée lorsqu'il y a une erreur de validation
class ValidationException implements Exception {
  final String message;
  
  ValidationException({this.message = 'Erreur de validation'});
}
