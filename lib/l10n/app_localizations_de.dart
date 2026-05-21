// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Aufzugswartungssystem';

  @override
  String get loginTitle => 'Anmelden';

  @override
  String get loginEmailLabel => 'E-Mail';

  @override
  String get loginPasswordLabel => 'Passwort';

  @override
  String get loginButton => 'Einloggen';

  @override
  String get homeActiveFaults => 'Aktive Störungen';

  @override
  String get homeDailyAgenda => 'Tagesordnung';
}
