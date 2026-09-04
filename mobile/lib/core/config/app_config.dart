abstract final class AppConfig {
  // Nome temporario: alterar aqui quando a marca oficial for escolhida.
  static const appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Garagem',
  );

  // 10.0.2.2 aponta para o localhost do computador no emulador Android.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );
}
