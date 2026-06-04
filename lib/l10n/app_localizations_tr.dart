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

  @override
  String get loginSubTitle => 'Hesabınıza erişmek için bilgilerinizi girin.';

  @override
  String get loginEmailValidationErrorEmpty =>
      'Lütfen e-posta adresinizi girin.';

  @override
  String get loginEmailValidationErrorInvalid =>
      'Geçerli bir e-posta adresi girin.';

  @override
  String get loginPasswordValidationErrorEmpty => 'Lütfen şifrenizi girin.';

  @override
  String get loginPasswordValidationErrorLength =>
      'Şifre en az 6 karakter olmalıdır.';

  @override
  String get loginSecureConnection => 'Güvenli Bağlantı';

  @override
  String get appSubTitle => 'Bakım & Arıza Takip Sistemi';

  @override
  String get maintenanceFormTitle => 'Yeni Bakım Formu';

  @override
  String get maintenanceSavedTitle => 'Bakım Kaydedildi';

  @override
  String get maintenanceSavedConfirm => 'Tamam';

  @override
  String maintenanceSaveError(String error) {
    return 'Kayıt sırasında hata oluştu: $error';
  }

  @override
  String get maintenanceSavePrevention =>
      'Lütfen kaydetme işlemi tamamlanana kadar bekleyin.';

  @override
  String get maintenanceSessionError => 'Oturum bilgisi alınamadı.';

  @override
  String get maintenanceSignatureError =>
      'Lütfen hem teknisyen hem de müşteri imzasını tamamlayın.';

  @override
  String get maintenanceChecklistSection => 'Kontrol Listesi';

  @override
  String get maintenanceChecklistEmpty => 'Aktif kontrol öğesi bulunamadı.';

  @override
  String maintenanceChecklistProgress(int checked, int total) {
    return '$checked / $total tamamlandı';
  }

  @override
  String maintenanceChecklistLoadError(String error) {
    return 'Kontrol listesi yüklenemedi: $error';
  }

  @override
  String get maintenancePhotosSection => 'Fotoğraflar';

  @override
  String get maintenancePhotosCamera => 'Kamera';

  @override
  String get maintenancePhotosGallery => 'Galeri';

  @override
  String get maintenancePhotosRemoveTooltip => 'Fotoğrafı kaldır';

  @override
  String get maintenancePhotosEmpty => 'Henüz fotoğraf eklenmedi.';

  @override
  String get maintenanceNotesSection => 'Bakım Notları';

  @override
  String get maintenanceNotesHint =>
      'Yapılan işlemleri, değiştirilen parçaları vb. buraya yazın...';

  @override
  String get maintenanceSignaturesSection => 'İmzalar';

  @override
  String get maintenanceSignatureTechLabel => 'Teknisyen İmzası';

  @override
  String get maintenanceSignatureCustLabel => 'Müşteri İmzası';

  @override
  String get maintenanceSignatureClear => 'Temizle';

  @override
  String get maintenanceSubmitButton => 'Bakımı Kaydet';

  @override
  String get maintenanceSavingMessage => 'Kaydediliyor...';

  @override
  String generalError(String error) {
    return 'Hata: $error';
  }

  @override
  String get generalRetry => 'Tekrar Dene';

  @override
  String get generalCancel => 'İptal';
}
