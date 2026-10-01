abstract final class AppConfig {
  // Identidade oficial do produto.
  static const appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Garona',
  );

  // 10.0.2.2 aponta para o localhost do computador no emulador Android.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  static String? resolveApiUrl(String? value) {
    if (value == null || value.isEmpty) return null;
    final uri = Uri.parse(value);
    if (uri.hasScheme) return value;

    final apiUri = Uri.parse(apiBaseUrl);
    final origin = apiUri.replace(path: '/', query: null, fragment: null);
    return origin.resolve(value).toString();
  }
}
