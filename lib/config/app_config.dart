class AppConfig {
  // true = localhost, false = Render backend.
  static const bool useLocalhost = false;

  static const String apiBaseUrl = useLocalhost
      ? 'http://localhost:1337/api'
      :'https://informatik-projekt-backend.onrender.com/api';

  static const String vapidKey =
      'BJVJQ06DQ1EfLmp139h21lWR7Sjga7o0iNAoIbeeh2BIqEwsVU_xlGIvaXCxGZ4jwzJkeNyqrHNhUkzsMxZRVhM';

  static const String storageTokenKey = 'token';
}
