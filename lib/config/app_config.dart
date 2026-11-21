class AppConfig {
  // API Configuration
  bool debug = true;

  static String apiBaseUrl = "";

  // Notification Configuration
  static const String vapidKey =
      'BJVJQ06DQ1EfLmp139h21lWR7Sjga7o0iNAoIbeeh2BIqEwsVU_xlGIvaXCxGZ4jwzJkeNyqrHNhUkzsMxZRVhM';

  // Secure Storage Keys
  static const String storageTokenKey = 'token';

  AppConfig() {
    apiBaseUrl = debug ? "http://localhost:1337/api" :'https://informatik-projekt-backend.onrender.com/api';
  }
}
