enum AppEnvironment {
  dev('dev'),
  staging('staging'),
  prod('prod');

  const AppEnvironment(this.value);

  final String value;

  static const String rawValue = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static AppEnvironment get current {
    return AppEnvironment.values.firstWhere(
      (environment) => environment.value == rawValue,
      orElse: () {
        throw StateError(
          'Invalid APP_ENV value: $rawValue. '
          'Expected one of: dev, staging, prod.',
        );
      },
    );
  }

  static void validate() {
    current;
  }
}
