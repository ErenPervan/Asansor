// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Elevator Maintenance System';

  @override
  String get loginTitle => 'Login';

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginButton => 'Sign In';

  @override
  String get homeActiveFaults => 'Active Faults';

  @override
  String get homeDailyAgenda => 'Daily Agenda';

  @override
  String get loginSubTitle => 'Enter your details to access your account.';

  @override
  String get loginEmailValidationErrorEmpty =>
      'Please enter your email address.';

  @override
  String get loginEmailValidationErrorInvalid =>
      'Please enter a valid email address.';

  @override
  String get loginPasswordValidationErrorEmpty => 'Please enter your password.';

  @override
  String get loginPasswordValidationErrorLength =>
      'Password must be at least 6 characters.';

  @override
  String get loginSecureConnection => 'Secure Connection';

  @override
  String get appSubTitle => 'Maintenance & Fault Tracking System';

  @override
  String get maintenanceFormTitle => 'New Maintenance Form';

  @override
  String get maintenanceSavedTitle => 'Maintenance Saved';

  @override
  String get maintenanceSavedConfirm => 'OK';

  @override
  String maintenanceSaveError(String error) {
    return 'Error occurred during save: $error';
  }

  @override
  String get maintenanceSavePrevention =>
      'Please wait until the save operation completes.';

  @override
  String get maintenanceSessionError =>
      'Session information could not be retrieved.';

  @override
  String get maintenanceSignatureError =>
      'Please complete both the technician and customer signatures.';

  @override
  String get maintenanceChecklistSection => 'Checklist';

  @override
  String get maintenanceChecklistEmpty => 'No active checklist items found.';

  @override
  String maintenanceChecklistProgress(int checked, int total) {
    return '$checked / $total completed';
  }

  @override
  String maintenanceChecklistLoadError(String error) {
    return 'Could not load checklist: $error';
  }

  @override
  String get maintenancePhotosSection => 'Photos';

  @override
  String get maintenancePhotosCamera => 'Camera';

  @override
  String get maintenancePhotosGallery => 'Gallery';

  @override
  String get maintenancePhotosRemoveTooltip => 'Remove photo';

  @override
  String get maintenancePhotosEmpty => 'No photos added yet.';

  @override
  String get maintenanceNotesSection => 'Maintenance Notes';

  @override
  String get maintenanceNotesHint =>
      'Enter actions taken, parts replaced, etc. here...';

  @override
  String get maintenanceSignaturesSection => 'Signatures';

  @override
  String get maintenanceSignatureTechLabel => 'Technician Signature';

  @override
  String get maintenanceSignatureCustLabel => 'Customer Signature';

  @override
  String get maintenanceSignatureClear => 'Clear';

  @override
  String get maintenanceSubmitButton => 'Save Maintenance';

  @override
  String get maintenanceSavingMessage => 'Saving...';

  @override
  String generalError(String error) {
    return 'Error: $error';
  }

  @override
  String get generalRetry => 'Retry';

  @override
  String get generalCancel => 'Cancel';
}
