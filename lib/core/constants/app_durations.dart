/// Uygulama genelinde standart animasyon ve bildirim süreleri.
abstract class AppDurations {
  /// Bilgi SnackBar'ları için (4 sn).
  static const snackBarInfo = Duration(seconds: 4);

  /// Hata SnackBar'ları için — daha uzun okunma süresi (6 sn).
  static const snackBarError = Duration(seconds: 6);

  /// Başarı SnackBar'ları için (3 sn).
  static const snackBarSuccess = Duration(seconds: 3);

  /// Animasyon geçişleri için (300 ms).
  static const animationDefault = Duration(milliseconds: 300);
}
