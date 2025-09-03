import 'package:internet_connection_checker/internet_connection_checker.dart';

/// Interface pour vérifier la connectivité réseau
abstract class NetworkInfo {
  /// Vérifie si l'appareil est connecté à Internet
  Future<bool> get isConnected;
}

/// Implémentation de NetworkInfo utilisant InternetConnectionChecker
class NetworkInfoImpl implements NetworkInfo {
  final InternetConnectionChecker connectionChecker;

  NetworkInfoImpl(this.connectionChecker);

  @override
  Future<bool> get isConnected => connectionChecker.hasConnection;
}
