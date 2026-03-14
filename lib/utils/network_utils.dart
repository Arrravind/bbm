import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkUtils {
  static final Connectivity _connectivity = Connectivity();

  // Check if device has internet connection
  static Future<bool> hasInternetConnection() async {
    final result = await _connectivity.checkConnectivity();
    return _isConnected(result);
  }

  // Subscribe to connectivity changes
  static Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(_isConnected);
  }

  // Helper method to determine connection status
  static bool _isConnected(ConnectivityResult result) {
    return result != ConnectivityResult.none;
  }

  // Check connectivity and throw exception if offline
  static Future<void> checkConnectivity() async {
    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      throw NetworkException('No internet connection. Please check your connection and try again.');
    }
  }
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  
  @override
  String toString() => 'NetworkException: $message';
}
