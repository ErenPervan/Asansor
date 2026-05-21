// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Asansör Bakım Sistemi';

  @override
  String get loginTitle => 'Giriş Yap';

  @override
  String get loginEmailLabel => 'E-posta';

  @override
  String get loginPasswordLabel => 'Şifre';

  @override
  String get loginButton => 'Giriş';

  @override
  String get homeActiveFaults => 'Aktif Arızalar';

  @override
  String get homeDailyAgenda => 'Günlük Ajandam';
}
