import 'package:asansor/core/enums/app_enums.dart';

/// Uygulamadaki her yetkilendirme kararını temsil eden merkezi enum.
///
/// Bir widgette veya route'da `role == UserRole.X` yazmak yerine
/// `profile.can(AppCapability.Y)` kullanılır. Bu sayede roller
/// değişse bile tek bir dosyada güncelleme yeterli olur.
enum AppCapability {
  // ── Yönetici (Admin) Yetenekleri ──────────────────────────────────────────

  /// /admin/* rotalarına ve yönetim paneline erişim
  accessAdminPanel,

  /// Tüm asansörleri görebilme (filo yönetimi)
  viewAllElevators,

  /// Asansör ekleme, düzenleme ve silme
  manageElevators,

  /// Kullanıcı yönetimi ekranına erişim ve rol atama
  manageUsers,

  /// Bakım görevi atama ve planlama
  assignMaintenance,

  /// Tüm teknisyenlerin program takvimini görme
  viewAllSchedules,

  /// Yönetici takvim görünümüne erişim (/admin/calendar)
  viewAdminCalendar,

  /// İstatistik gösterge panosuna erişim
  viewAdminStats,

  /// Kontrol listesi (checklist) şablonlarını yönetme
  manageChecklists,

  /// Herhangi bir arızayı çözüldü olarak işaretleme
  resolveAnyFault,

  /// Tüm arızaları görme (tüm asansörler)
  viewAllFaults,

  /// QR kodu oluşturma (asansör bazında)
  generateQrCode,

  /// Teknisyen çakışma yönetimi ekranına erişim
  viewConflicts,

  // ── Teknisyen Yetenekleri ─────────────────────────────────────────────────

  /// Bakım formu doldurma ve kaydetme
  logMaintenance,

  /// Yeni arıza bildirme
  reportFault,

  /// QR kod tarama ile asansör sayfasına gitme
  scanQrCode,

  /// Kendi görev listesini görme
  viewMySchedules,

  // ── Müşteri Yetenekleri ───────────────────────────────────────────────────

  /// Kendi asansör gösterge panosunu görme (/customer/dashboard)
  viewOwnDashboard,

  /// Kendi asansörüne ait arızaları görme
  viewOwnFaults,
}

// ── Capability Matrix ─────────────────────────────────────────────────────────

/// Her [UserRole] için geçerli olan [AppCapability] kümesini tanımlar.
/// Tek bir yerde tutulduğu için rol değişiklikleri sadece buraya yansır.
const Map<UserRole, Set<AppCapability>> capabilityMatrix = {
  UserRole.admin: {
    AppCapability.accessAdminPanel,
    AppCapability.viewAllElevators,
    AppCapability.manageElevators,
    AppCapability.manageUsers,
    AppCapability.assignMaintenance,
    AppCapability.viewAllSchedules,
    AppCapability.viewAdminCalendar,
    AppCapability.viewAdminStats,
    AppCapability.manageChecklists,
    AppCapability.resolveAnyFault,
    AppCapability.viewAllFaults,
    AppCapability.generateQrCode,
    AppCapability.viewConflicts,
    AppCapability.reportFault,
    AppCapability.scanQrCode,
    AppCapability.logMaintenance,
  },
  UserRole.technician: {
    AppCapability.viewAllElevators,
    AppCapability.viewAllFaults,
    AppCapability.viewMySchedules,
    AppCapability.logMaintenance,
    AppCapability.reportFault,
    AppCapability.scanQrCode,
  },
  UserRole.customer: {
    AppCapability.viewOwnDashboard,
    AppCapability.viewOwnFaults,
    AppCapability.reportFault,
  },
};
