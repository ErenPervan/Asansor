import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('tr'),
  ];

  /// Uygulama genel başlığı
  ///
  /// In tr, this message translates to:
  /// **'Asansör Bakım Sistemi'**
  String get appTitle;

  /// No description provided for @loginTitle.
  ///
  /// In tr, this message translates to:
  /// **'Giriş Yap'**
  String get loginTitle;

  /// No description provided for @loginEmailLabel.
  ///
  /// In tr, this message translates to:
  /// **'E-posta'**
  String get loginEmailLabel;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In tr, this message translates to:
  /// **'Şifre'**
  String get loginPasswordLabel;

  /// No description provided for @loginButton.
  ///
  /// In tr, this message translates to:
  /// **'Giriş'**
  String get loginButton;

  /// No description provided for @homeActiveFaults.
  ///
  /// In tr, this message translates to:
  /// **'Aktif Arızalar'**
  String get homeActiveFaults;

  /// No description provided for @homeDailyAgenda.
  ///
  /// In tr, this message translates to:
  /// **'Günlük Ajandam'**
  String get homeDailyAgenda;

  /// No description provided for @loginSubTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesabınıza erişmek için bilgilerinizi girin.'**
  String get loginSubTitle;

  /// No description provided for @loginEmailValidationErrorEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen e-posta adresinizi girin.'**
  String get loginEmailValidationErrorEmpty;

  /// No description provided for @loginEmailValidationErrorInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir e-posta adresi girin.'**
  String get loginEmailValidationErrorInvalid;

  /// No description provided for @loginPasswordValidationErrorEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen şifrenizi girin.'**
  String get loginPasswordValidationErrorEmpty;

  /// No description provided for @loginPasswordValidationErrorLength.
  ///
  /// In tr, this message translates to:
  /// **'Şifre en az 6 karakter olmalıdır.'**
  String get loginPasswordValidationErrorLength;

  /// No description provided for @loginSecureConnection.
  ///
  /// In tr, this message translates to:
  /// **'Güvenli Bağlantı'**
  String get loginSecureConnection;

  /// No description provided for @appSubTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bakım & Arıza Takip Sistemi'**
  String get appSubTitle;

  /// No description provided for @maintenanceFormTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Bakım Formu'**
  String get maintenanceFormTitle;

  /// No description provided for @maintenanceSavedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bakım Kaydedildi'**
  String get maintenanceSavedTitle;

  /// No description provided for @maintenanceSavedConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Tamam'**
  String get maintenanceSavedConfirm;

  /// No description provided for @maintenanceSaveError.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt sırasında hata oluştu: {error}'**
  String maintenanceSaveError(String error);

  /// No description provided for @maintenanceSavePrevention.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen kaydetme işlemi tamamlanana kadar bekleyin.'**
  String get maintenanceSavePrevention;

  /// No description provided for @maintenanceSessionError.
  ///
  /// In tr, this message translates to:
  /// **'Oturum bilgisi alınamadı.'**
  String get maintenanceSessionError;

  /// No description provided for @maintenanceSignatureError.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen hem teknisyen hem de müşteri imzasını tamamlayın.'**
  String get maintenanceSignatureError;

  /// No description provided for @maintenanceChecklistSection.
  ///
  /// In tr, this message translates to:
  /// **'Kontrol Listesi'**
  String get maintenanceChecklistSection;

  /// No description provided for @maintenanceChecklistEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Aktif kontrol öğesi bulunamadı.'**
  String get maintenanceChecklistEmpty;

  /// No description provided for @maintenanceChecklistProgress.
  ///
  /// In tr, this message translates to:
  /// **'{checked} / {total} tamamlandı'**
  String maintenanceChecklistProgress(int checked, int total);

  /// No description provided for @maintenanceChecklistLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Kontrol listesi yüklenemedi: {error}'**
  String maintenanceChecklistLoadError(String error);

  /// No description provided for @maintenancePhotosSection.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraflar'**
  String get maintenancePhotosSection;

  /// No description provided for @maintenancePhotosCamera.
  ///
  /// In tr, this message translates to:
  /// **'Kamera'**
  String get maintenancePhotosCamera;

  /// No description provided for @maintenancePhotosGallery.
  ///
  /// In tr, this message translates to:
  /// **'Galeri'**
  String get maintenancePhotosGallery;

  /// No description provided for @maintenancePhotosRemoveTooltip.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğrafı kaldır'**
  String get maintenancePhotosRemoveTooltip;

  /// No description provided for @maintenancePhotosEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz fotoğraf eklenmedi.'**
  String get maintenancePhotosEmpty;

  /// No description provided for @maintenanceNotesSection.
  ///
  /// In tr, this message translates to:
  /// **'Bakım Notları'**
  String get maintenanceNotesSection;

  /// No description provided for @maintenanceNotesHint.
  ///
  /// In tr, this message translates to:
  /// **'Yapılan işlemleri, değiştirilen parçaları vb. buraya yazın...'**
  String get maintenanceNotesHint;

  /// No description provided for @maintenanceSignaturesSection.
  ///
  /// In tr, this message translates to:
  /// **'İmzalar'**
  String get maintenanceSignaturesSection;

  /// No description provided for @maintenanceSignatureTechLabel.
  ///
  /// In tr, this message translates to:
  /// **'Teknisyen İmzası'**
  String get maintenanceSignatureTechLabel;

  /// No description provided for @maintenanceSignatureCustLabel.
  ///
  /// In tr, this message translates to:
  /// **'Müşteri İmzası'**
  String get maintenanceSignatureCustLabel;

  /// No description provided for @maintenanceSignatureClear.
  ///
  /// In tr, this message translates to:
  /// **'Temizle'**
  String get maintenanceSignatureClear;

  /// No description provided for @maintenanceSubmitButton.
  ///
  /// In tr, this message translates to:
  /// **'Bakımı Kaydet'**
  String get maintenanceSubmitButton;

  /// No description provided for @maintenanceSavingMessage.
  ///
  /// In tr, this message translates to:
  /// **'Kaydediliyor...'**
  String get maintenanceSavingMessage;

  /// No description provided for @generalError.
  ///
  /// In tr, this message translates to:
  /// **'Hata: {error}'**
  String generalError(String error);

  /// No description provided for @generalRetry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar Dene'**
  String get generalRetry;

  /// No description provided for @generalCancel.
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get generalCancel;

  /// No description provided for @navBarFleet.
  ///
  /// In tr, this message translates to:
  /// **'Filo'**
  String get navBarFleet;

  /// No description provided for @navBarFaults.
  ///
  /// In tr, this message translates to:
  /// **'Arızalar'**
  String get navBarFaults;

  /// No description provided for @navBarSchedule.
  ///
  /// In tr, this message translates to:
  /// **'Program'**
  String get navBarSchedule;

  /// No description provided for @navBarLog.
  ///
  /// In tr, this message translates to:
  /// **'Günlük'**
  String get navBarLog;

  /// No description provided for @navBarAdminOnlyTooltip.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca yöneticiler erişebilir'**
  String get navBarAdminOnlyTooltip;

  /// No description provided for @faultDetailResolveButton.
  ///
  /// In tr, this message translates to:
  /// **'Arızayı Onar'**
  String get faultDetailResolveButton;

  /// No description provided for @faultDetailConfirmResolveButton.
  ///
  /// In tr, this message translates to:
  /// **'Evet, Onar'**
  String get faultDetailConfirmResolveButton;

  /// No description provided for @faultDetailResolveSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Arıza başarıyla onarıldı olarak işaretlendi.'**
  String get faultDetailResolveSuccess;

  /// No description provided for @faultDetailReopenSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Arıza yeniden açıldı.'**
  String get faultDetailReopenSuccess;

  /// No description provided for @faultListRefresh.
  ///
  /// In tr, this message translates to:
  /// **'Yenile'**
  String get faultListRefresh;

  /// No description provided for @faultSidePanelGoToElevator.
  ///
  /// In tr, this message translates to:
  /// **'Asansör Detayına Git'**
  String get faultSidePanelGoToElevator;

  /// No description provided for @mainHiveRecoveryMessage.
  ///
  /// In tr, this message translates to:
  /// **'Yerel veri önbelleği bozulmuştu. Veriler sıfırlandı, uygulamanız güvenle çalışmaya devam ediyor.'**
  String get mainHiveRecoveryMessage;

  /// No description provided for @urgentFaultTag.
  ///
  /// In tr, this message translates to:
  /// **'ACİL ARIZA'**
  String get urgentFaultTag;

  /// No description provided for @faultReportReceived.
  ///
  /// In tr, this message translates to:
  /// **'Arıza bildirimi alındı.'**
  String get faultReportReceived;

  /// No description provided for @activeFaultsCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} Aktif'**
  String activeFaultsCount(int count);

  /// No description provided for @noActiveFaults.
  ///
  /// In tr, this message translates to:
  /// **'Aktif arıza bulunmuyor.'**
  String get noActiveFaults;

  /// No description provided for @urgentInterventionWaiting.
  ///
  /// In tr, this message translates to:
  /// **'Acil Müdahale Bekleyenler'**
  String get urgentInterventionWaiting;

  /// No description provided for @seeAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü Gör'**
  String get seeAll;

  /// No description provided for @critical.
  ///
  /// In tr, this message translates to:
  /// **'Kritik'**
  String get critical;

  /// No description provided for @high.
  ///
  /// In tr, this message translates to:
  /// **'Yüksek'**
  String get high;

  /// No description provided for @daysAgo.
  ///
  /// In tr, this message translates to:
  /// **'{days} gün önce'**
  String daysAgo(int days);

  /// No description provided for @hoursAgo.
  ///
  /// In tr, this message translates to:
  /// **'{hours} sa önce'**
  String hoursAgo(int hours);

  /// No description provided for @minutesAgo.
  ///
  /// In tr, this message translates to:
  /// **'{minutes} dk önce'**
  String minutesAgo(int minutes);

  /// No description provided for @justNow.
  ///
  /// In tr, this message translates to:
  /// **'Şimdi'**
  String get justNow;

  /// No description provided for @elevator.
  ///
  /// In tr, this message translates to:
  /// **'Asansör'**
  String get elevator;

  /// No description provided for @photoAddError.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf eklenemedi: {error}'**
  String photoAddError(String error);

  /// No description provided for @photosAddError.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraflar eklenemedi: {error}'**
  String photosAddError(String error);

  /// No description provided for @back.
  ///
  /// In tr, this message translates to:
  /// **'Geri'**
  String get back;

  /// No description provided for @operation.
  ///
  /// In tr, this message translates to:
  /// **'Operasyon'**
  String get operation;

  /// No description provided for @monthlyPeriodicMaintenanceForm.
  ///
  /// In tr, this message translates to:
  /// **'Aylık Periyodik Bakım Formu'**
  String get monthlyPeriodicMaintenanceForm;

  /// No description provided for @inProgress.
  ///
  /// In tr, this message translates to:
  /// **'Devam Ediyor'**
  String get inProgress;

  /// No description provided for @recordNo.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt No: {no}'**
  String recordNo(String no);

  /// No description provided for @unknownError.
  ///
  /// In tr, this message translates to:
  /// **'Bilinmeyen hata'**
  String get unknownError;

  /// No description provided for @preparingInfo.
  ///
  /// In tr, this message translates to:
  /// **'Bilgileriniz hazırlanıyor'**
  String get preparingInfo;

  /// No description provided for @checkingProfile.
  ///
  /// In tr, this message translates to:
  /// **'Profil ve yetki bilgileri kontrol ediliyor.'**
  String get checkingProfile;

  /// No description provided for @connectionError.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı Hatası'**
  String get connectionError;

  /// No description provided for @logout.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış Yap'**
  String get logout;

  /// No description provided for @offlineSyncMessage.
  ///
  /// In tr, this message translates to:
  /// **'Çevrimdışı Mod – Değişiklikler kaydediliyor'**
  String get offlineSyncMessage;

  /// No description provided for @syncingMessage.
  ///
  /// In tr, this message translates to:
  /// **'Sunucu ile eşitleniyor...'**
  String get syncingMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
