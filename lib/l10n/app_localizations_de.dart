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

  @override
  String get loginSubTitle =>
      'Geben Sie Ihre Daten ein, um auf Ihr Konto zuzugreifen.';

  @override
  String get loginEmailValidationErrorEmpty =>
      'Bitte geben Sie Ihre E-Mail-Adresse ein.';

  @override
  String get loginEmailValidationErrorInvalid =>
      'Bitte geben Sie eine gültige E-Mail-Adresse ein.';

  @override
  String get loginPasswordValidationErrorEmpty =>
      'Bitte geben Sie Ihr Passwort ein.';

  @override
  String get loginPasswordValidationErrorLength =>
      'Das Passwort muss mindestens 6 Zeichen lang sein.';

  @override
  String get loginSecureConnection => 'Sichere Verbindung';

  @override
  String get appSubTitle => 'Wartungs- & Störungsverfolgungssystem';

  @override
  String get maintenanceFormTitle => 'Neues Wartungsformular';

  @override
  String get maintenanceSavedTitle => 'Wartung gespeichert';

  @override
  String get maintenanceSavedConfirm => 'OK';

  @override
  String maintenanceSaveError(String error) {
    return 'Fehler beim Speichern aufgetreten: $error';
  }

  @override
  String get maintenanceSavePrevention =>
      'Bitte warten Sie, bis der Speichervorgang abgeschlossen ist.';

  @override
  String get maintenanceSessionError =>
      'Sitzungsinformationen konnten nicht abgerufen werden.';

  @override
  String get maintenanceSignatureError =>
      'Bitte vervollständigen Sie beide Unterschriften.';

  @override
  String get maintenanceChecklistSection => 'Checkliste';

  @override
  String get maintenanceChecklistEmpty =>
      'Keine aktiven Checklisten-Elemente gefunden.';

  @override
  String maintenanceChecklistProgress(int checked, int total) {
    return '$checked / $total abgeschlossen';
  }

  @override
  String maintenanceChecklistLoadError(String error) {
    return 'Checkliste konnte nicht geladen werden: $error';
  }

  @override
  String get maintenancePhotosSection => 'Fotos';

  @override
  String get maintenancePhotosCamera => 'Kamera';

  @override
  String get maintenancePhotosGallery => 'Galerie';

  @override
  String get maintenancePhotosRemoveTooltip => 'Foto entfernen';

  @override
  String get maintenancePhotosEmpty => 'Noch keine Fotos hinzugefügt.';

  @override
  String get maintenanceNotesSection => 'Wartungsnotizen';

  @override
  String get maintenanceNotesHint =>
      'Geben Sie hier durchgeführte Aktionen, ausgetauschte Teile usw. ein...';

  @override
  String get maintenanceSignaturesSection => 'Unterschriften';

  @override
  String get maintenanceSignatureTechLabel => 'Unterschrift des Technikers';

  @override
  String get maintenanceSignatureCustLabel => 'Unterschrift des Kunden';

  @override
  String get maintenanceSignatureClear => 'Löschen';

  @override
  String get maintenanceSubmitButton => 'Wartung speichern';

  @override
  String get maintenanceSavingMessage => 'Wird gespeichert...';

  @override
  String generalError(String error) {
    return 'Fehler: $error';
  }

  @override
  String get generalRetry => 'Erneut versuchen';

  @override
  String get generalCancel => 'Abbrechen';

  @override
  String get navBarFleet => 'Flotte';

  @override
  String get navBarFaults => 'Störungen';

  @override
  String get navBarSchedule => 'Zeitplan';

  @override
  String get navBarLog => 'Protokoll';

  @override
  String get navBarAdminOnlyTooltip => 'Nur Administratoren haben Zugriff';

  @override
  String get faultDetailResolveButton => 'Störung beheben';

  @override
  String get faultDetailConfirmResolveButton => 'Ja, beheben';

  @override
  String get faultDetailResolveSuccess =>
      'Störung erfolgreich als behoben markiert.';

  @override
  String get faultDetailReopenSuccess => 'Störung wiedereröffnet.';

  @override
  String get faultListRefresh => 'Aktualisieren';

  @override
  String get faultSidePanelGoToElevator => 'Zum Aufzug-Detail gehen';

  @override
  String get mainHiveRecoveryMessage =>
      'Lokaler Datencache war beschädigt. Daten wurden zurückgesetzt, Ihre App läuft sicher weiter.';
}
