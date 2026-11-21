class AppConfig {
  // true = localhost, false = Render backend.
  static const bool useLocalhost = true;

  static const String apiBaseUrl = useLocalhost
      ? 'https://informatik-projekt-backend.onrender.com/api'
      : 'http://localhost:1337/api';

  static const String vapidKey =
      'BJVJQ06DQ1EfLmp139h21lWR7Sjga7o0iNAoIbeeh2BIqEwsVU_xlGIvaXCxGZ4jwzJkeNyqrHNhUkzsMxZRVhM';

  static const String storageTokenKey = 'token';
}
