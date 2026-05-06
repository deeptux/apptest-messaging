const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

String requireApiBaseUrl() {
  if (kApiBaseUrl.isEmpty) {
    throw StateError(
      'Missing API_BASE_URL. Run with: '
      'flutter run --dart-define=API_BASE_URL=http://localhost:8080',
    );
  }
  return kApiBaseUrl.replaceAll(RegExp(r'/$'), '');
}
