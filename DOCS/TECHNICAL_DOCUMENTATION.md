# Asansör Uygulaması — Teknik Dokümantasyon

Bu doküman, proje yapısını, mimari kararlarını, ana bileşenleri, veri akışını, çalıştırma ve dağıtım detaylarını içerir. Başka bir geliştirici veya AI ajanı bu dokümanı okuduğunda uygulamayı çalıştırabilmeli, bakımını yapabilmeli ve yeni özellik ekleyebilmelidir.

> [!IMPORTANT]
> Projenin ana referans noktası ve güncel durumu için [PROJECT_KNOWLEDGE_BASE.md](PROJECT_KNOWLEDGE_BASE.md) dosyasını kontrol edin.

---

**Hızlı Başlangıç: Ajan Kuralları**
Bu proje 3 farklı ajan (flutter-dev, supabase-dev, qa-tester) tarafından yönetilmektedir. Detaylı kurallar için [AGENTS.md](../AGENTS.md) dosyasına bakınız.
- **Frontend Değişikliği:** `lib/` dizini.
- **Backend/DB Değişikliği:** `supabase/` dizini.
- **Testler:** `test/` dizini.

---

**Hızlı Dosya Rehberi**
- Proje tanımı: [pubspec.yaml](pubspec.yaml)
- Uygulama giriş noktası: [lib/main.dart](lib/main.dart)
- Router / GoRouter: [lib/core/router/app_router.dart](lib/core/router/app_router.dart)
- Supabase migration ve fonksiyonlar: [supabase/](supabase/)
  - DB webhook örneği: [supabase/database_webhook_setup.sql](supabase/database_webhook_setup.sql)
  - Edge Function: [supabase/functions/send-notification/index.ts](supabase/functions/send-notification/index.ts)
  - FCM yardımcı: [supabase/functions/_shared/fcm_v1.ts](supabase/functions/_shared/fcm_v1.ts)
- Önemli feature örnekleri: `lib/features/` (asansör, bakım, admin, auth, bildirim)
  - Asansör detay görünümü: [lib/features/elevator/views/elevator_detail_view.dart](lib/features/elevator/views/elevator_detail_view.dart)
  - Asansör provider: [lib/features/elevator/providers/elevator_providers.dart](lib/features/elevator/providers/elevator_providers.dart)

---

**Teknoloji Yığını (Dependencies)**
(ana paketler — ayrıntılar için [pubspec.yaml](pubspec.yaml))
- Flutter SDK
- State & DI: `flutter_riverpod`
- Navigation: `go_router`
- Backend: `supabase_flutter`
- Push: `firebase_messaging`, Edge Functions + FCM HTTP v1
- Offline: `hive`, `hive_flutter`, `connectivity_plus`
- Diğer: `flutter_dotenv` (env), `mobile_scanner` (QR/scan), `image_picker`, `flutter_map`, `latlong2`, `flutter_local_notifications`, `pdf`/`printing`.

---

**Uygulama Mimarisine Genel Bakış**
1. App Shell
   - Giriş noktası `lib/main.dart` — uygulama başlatma, hata yakalama, Firebase & Supabase init, Hive kutularını açma, `NotificationService` başlatma.
   - UI: `MaterialApp.router` ile `appRouter` (GoRouter) kullanılıyor. Görünümler `lib/features/*/views` altında.

2. Routing
   - GoRouter kullanılıyor; `app_router.dart` içinde Supabase auth stream'i dinlenerek yönlendirme (redirect) mantığı uygulanmış.

3. State Management
   - `flutter_riverpod` kullanımı: Her feature kendi `providers` klasörü ile organize edilmiş (ör. `elevator_providers.dart`, `auth_providers.dart`).
   - Global state örnekleri: `autoSyncProvider` (main.dart içinde `ref.watch(autoSyncProvider)` ile uygulama ömrü boyunca çalışacak otomatik sync dinleyicisi).

4. Servisler & Altyapı
   - Supabase: veri saklama, auth, RLS (migrationlar arasında RLS etkinleştiren dosya var).
   - Firebase: FCM token yönetimi ve mesaj alma; `NotificationService` yerel bildirim kanal ve dinleyiciler kuruyor.
   - Edge Functions: bildirim gönderme için `send-notification` fonksiyonu, ayrıca `notify-technician` gibi işlevler.
   - Offline-first: Yazma işlemleri önce bir Hive tabanlı `syncQueueBox`'a yazılıyor, `SyncQueueService` bunları arka planda Supabase'e gönderiyor. Aynı şekilde read cache box'lar (elevatorsCacheBoxName vb.) sayesinde çevrimdışı okunabilirlik sağlanıyor.

5. Hata Yönetimi
   - `ErrorHandler` genel hataları log'lamak için kullanılıyor; Flutter hataları `FlutterError.onError` ile, platform asenkron hatalar `PlatformDispatcher.onError` ile yakalanıyor. `ErrorBoundary` widget'ı özel crash UI sağlıyor.

---

**Veri Modeli ve Veritabanı Şeması**
Uygulamanın veri modeli Supabase (PostgreSQL) üzerinde barındırılmaktadır. Tüm ana tablolarda Row Level Security (RLS) aktif durumdadır.

#### 1. `elevators` (Asansörler)
Asansör varlıklarını ve durumlarını tutar.
- `id` (UUID, PK): Benzersiz kimlik. Varsayılan: `uuid_generate_v4()`.
- `building_name` (Text): Bina adı.
- `address` (Text): Açık adres.
- `status` (Text): Mevcut durum (`Aktif`, `Arızalı`, `Bakımda`). Varsayılan: `Aktif`.
- `latitude`, `longitude` (Float8): Coğrafi konum.
- `maintenance_day` (Int4): Aylık periyodik bakım günü (1-28). Varsayılan: `1`.
- `model` (Text): Üretici ve model bilgisi.
- `capacity` (Int4): Kişi/Kilo kapasitesi.
- `last_inspection_date` (Timestamptz): Son legal muayene tarihi.
- `next_inspection_date` (Timestamptz): Gelecek muayene tarihi (Genellikle son muayeneden 1 yıl sonra).
- `inspection_status` (Enum): Muayene etiketi (`red`, `yellow`, `blue`, `green`, `none`).

#### 2. `fault_reports` (Arıza Raporları)
Bildirilen arızaları ve çözüm süreçlerini takip eder.
- `id` (UUID, PK): Benzersiz kimlik.
- `elevator_id` (UUID, FK): `elevators.id` referansı.
- `description` (Text): Arıza açıklaması.
- `fault_type` (Text): Arıza türü (`Mekanik`, `Elektrik`, `Mahsur` vb.).
- `priority` (Text): Öncelik (`Acil`, `Yüksek`, `Normal`, `Düşük`).
- `is_resolved` (Bool): Çözüldü mü? Varsayılan: `false`.
- `reported_at` (Timestamptz): Bildirim zamanı. Varsayılan: `now()`.
- `resolved_at` (Timestamptz): Çözüm zamanı.
- `resolution_notes` (Text): Çözüm notları.
- `photo_url` (Text): Arıza kanıt fotoğrafı (Storage URL).

#### 3. `maintenance_logs` (Bakım Kayıtları)
Gerçekleştirilen bakım işlemlerinin detaylarını tutar.
- `id` (UUID, PK): Benzersiz kimlik.
- `elevator_id` (UUID, FK): `elevators.id` referansı.
- `technician_id` (UUID, FK): `profiles.id` referansı.
- `maintenance_date` (Timestamptz): Bakım zamanı. Varsayılan: `now()`.
- `notes` (Text): Bakım notları.
- `checklist` (JSONB): Kontrol listesi maddeleri ve boolean durumları (`{ "item_id": true/false }`).
- `photos` (Text[]): Supabase Storage üzerindeki fotoğraf URL'leri dizisi.
- `signature_url` (Text): Teknisyen imza görseli URL'si.
- `customer_signature_url` (Text): Müşteri/Yetkili imza görseli URL'si.
- `pdf_url` (Text): Oluşturulan PDF raporunun URL'si.
- `is_approved` (Bool): Yönetici onayı durumu. Varsayılan: `false`.

#### 4. `maintenance_schedules` (Bakım Takvimi)
Planlanan görevleri yönetir.
- `id` (UUID, PK): Benzersiz kimlik.
- `elevator_id` (UUID, FK): `elevators.id` referansı.
- `technician_id` (UUID, FK): Atanan teknisyen (`auth.users.id`).
- `scheduled_date` (Timestamptz): Planlanan tarih.
- `task_type` (Text): Görev türü (`periodic_maintenance`, `emergency`, `repair`). Varsayılan: `periodic_maintenance`.
- `status` (Text): Durum (`pending`, `completed`, `cancelled`). Varsayılan: `pending`.
- `priority` (Text): Öncelik (`low`, `normal`, `high`, `emergency`). Varsayılan: `normal`.
- `created_at` (Timestamptz): Varsayılan: `now()`.
- `created_by` (UUID, FK): `auth.users.id` referansı.

#### 5. `profiles` (Kullanıcı Profilleri)
`auth.users` ile ilişkili ek kullanıcı bilgileri.
- `id` (UUID, PK): `auth.users.id` ile eşleşir.
- `full_name` (Text): Ad Soyad.
- `role` (Enum): Kullanıcı rolü (`admin`, `technician`, `customer`). Varsayılan: `technician`.
- `phone` (Text): İletişim numarası.
- `company_name` (Text): Firma adı.
- `fcm_token` (Text): Push bildirimleri için FCM v1 token'ı.
- `elevator_id` (UUID, FK): `customer` rolü için atanmış asansör.

#### 6. `notifications` (Bildirim Geçmişi)
Kullanıcılara gönderilen bildirimlerin kaydı.
- `id` (UUID, PK): Varsayılan: `gen_random_uuid()`.
- `user_id` (UUID, FK): `profiles.id` referansı.
- `title`, `body` (Text): Bildirim içeriği.
- `data_payload` (JSONB): Yönlendirme ve meta verisi (örn. `{ "route": "/home", "schedule_id": "..." }`).
- `is_read` (Bool): Okundu bilgisi. Varsayılan: `false`.
- `created_at` (Timestamptz): Varsayılan: `now()`.

#### 7. `checklist_items` (Kontrol Listesi Maddeleri)
Bakım sırasında doldurulan dinamik form maddeleri.
- `id` (UUID, PK): Varsayılan: `gen_random_uuid()`.
- `label` (Text): Madde başlığı.
- `description` (Text): Detaylı açıklama.
- `is_active` (Bool): Madde kullanımda mı? Varsayılan: `true`.
- **Örnek Maddeler:** "Kabin İçi Işıklandırma", "Kapı Sensörleri", "Fren Sistemleri", "Motor ve Ray Yağlama".

#### 8. `inspection_history` (Muayene Geçmişi)
Legal muayene kayıtları.
- `id` (UUID, PK): Varsayılan: `gen_random_uuid()`.
- `elevator_id` (UUID, FK): `elevators.id` referansı.
- `technician_id` (UUID, FK): Muayeneye katılan teknisyen.
- `inspection_date` (Timestamptz): Muayene tarihi.
- `status` (Enum): Alınan etiket (`red`, `yellow`, `blue`, `green`).
- `inspector_name` (Text): Muayeneyi yapan yetkili.
- `notes` (Text): Muayene notları.

---

**Edge Functions ve Bildirim Akışı**
- `send-notification` (Unified Edge Function): Projenin tek ve güncel bildirim fonksiyonudur. Firebase Cloud Messaging (FCM) HTTP v1 API kullanır.
  - **Akış:** Fonksiyon çağrıldığında `profiles` tablosundan hedef kullanıcının `fcm_token` bilgisini alır, push gönderir ve aynı zamanda `notifications` tablosuna bir kayıt ekler.
  - **Güvenlik:** RLS politikaları nedeniyle `service_role` yetkisiyle çalışır.
- `notify-technician` (Legacy): Bu fonksiyon kullanımdan kaldırılmış (decommissioned), tüm mantık `send-notification` içine taşınmıştır.
- `AutoScheduleService` (Dart Side): Her ayın başında `elevators.maintenance_day` alanına bakarak o ayın bakım planlarını (`maintenance_schedules`) otomatik oluşturur.

**Database Triggers (Veritabanı Tetikleyicileri)**
- `notify_on_schedule_insert`: `maintenance_schedules` tablosuna yeni bir kayıt (görev) eklendiğinde tetiklenir.
  - `notify_technician_on_assignment()` SQL fonksiyonunu çalıştırır.
  - Bu fonksiyon, `send-notification` Edge Function'ına HTTP POST isteği göndererek atanan teknisyene anlık bildirim ulaşmasını sağlar.


---

**Önemli Kod Bileşenleri ve Konumları**
- `lib/main.dart` — Uygulama başlangıcı, servis init, tema.
- `lib/core/router/app_router.dart` — GoRouter konfigürasyonu.
- `lib/core/services/`
  - `pdf_service.dart` — Kurumsal markalı PDF rapor oluşturma (Bakım ve Muayene raporları).
  - `auto_schedule_service.dart` — Periyodik bakım otomasyon mantığı.
  - `sync_queue_service.dart` — Offline-first senkronizasyon (Kuyruk yönetimi ve dosya yükleme sırası).
  - `notification_service.dart` — Firebase Messaging ve Local Notifications entegrasyonu.
  - `storage_service.dart` — Supabase Storage işlemleri. 
    - **Buckets:** `fault-images` (Arıza fotoğrafları), `maintenance-records` (Bakım fotoğrafları ve imzalar), `maintenance-reports` (PDF raporları).
  - `read_cache_service.dart` — Hive tabanlı offline okuma cache'i.

- `lib/features/*` — Domain feature'ları.
- `supabase/migrations/*` — DB şeması ve RLS politikaları.

---

**Teknik Detaylar: Çevrimdışı Senkronizasyon (Sync Queue)**
Uygulama "Offline-First" prensibiyle çalışır. `SyncQueueService` aşağıdaki karmaşık senkronizasyon mantığını (Flush) izler:
1. **Dosya Hazırlığı:** Kuyruktaki işlemin tipine göre yerel dosyalar (fotoğraflar, Base64 imzalar, PDF) belirlenir.
2. **Storage Yükleme Sırası:**
   - Önce fotoğraflar `maintenance-records` bucket'ına yüklenir.
   - Ardından teknikçi ve müşteri imzaları (PNG olarak) aynı bucket'a yüklenir.
   - Son olarak oluşturulan PDF raporu `maintenance-reports` bucket'ına yüklenir.
3. **URL Eşleştirme:** Storage'dan dönen tüm kamuya açık URL'ler veritabanı payload'una (JSON) enjekte edilir.
4. **Veritabanı Kaydı:** Nihai payload `maintenance_logs` veya `fault_reports` tablosuna `insert` edilir.
5. **Geriye Dönük Güncelleme:** Bakım tamamlanmışsa, ilgili `maintenance_schedules` kaydı `status = 'completed'` olarak güncellenir.
6. **Kuyruktan Silme:** İşlem tamamen başarılıysa Hive box'tan silinir, aksi halde bir sonraki senkronizasyon denemesi için saklanır.


---

**Önemli Dosya Linkleri**
- **Yapılandırma:** [.env](.env), [pubspec.yaml](pubspec.yaml)
- **Veritabanı:** [supabase/migrations/](supabase/migrations/)
- **Servisler:** 
  - [PdfService](lib/core/services/pdf_service.dart)
  - [SyncQueueService](lib/core/services/sync_queue_service.dart)
  - [AutoScheduleService](lib/core/services/auto_schedule_service.dart)
- **Modeller:**
  - [MaintenanceLogModel](lib/features/maintenance/models/maintenance_log_model.dart)
  - [ChecklistItemModel](lib/features/maintenance/models/checklist_item_model.dart)
  - [FaultReportModel](lib/features/fault/models/fault_report_model.dart)

---

**Çalıştırma & Geliştirme Rehberi (Local)**
1. Gerekli araçlar
   - Flutter SDK (projenin `environment.sdk` sürümünü kullanın).
   - Supabase CLI (Edge Functions deploy için), Deno (fonksiyonlar local testinde otomatik kullanılır).
   - Firebase Service Account JSON (Edge Function secret olarak eklenecek).

2. Adımlar (lokalde uygulamayı çalıştırmak)
   - Ortam değişkenleri: root `.env` dosyası kullanılıyor (projeye dahil). Gerekli .env içeriklerini proje sahibinden alın veya örnekleri ayarlayın.
   - Paketleri yükleyin:

```bash
flutter pub get
```

   - Supabase konfigurasyonu: `core/constants/supabase_constants.dart` içinde `supabaseUrl` ve `supabaseAnonKey` kullanılıyor. `.env` veya bu sabitler üzerinden sağlanmalıdır.
   - Firebase: `firebase_options.dart` dosyası projede var; yerel geliştirme için Firebase projesi doğru konfigürasyona sahip olmalıdır.
   - Çalıştır:

```bash
flutter run -d <device>
```

3. Edge Functions (bildirimler)
   - Secrets yükleyin (Supabase dashboard veya CLI): `FIREBASE_SERVICE_ACCOUNT_KEY` (JSON string), `SUPABASE_SERVICE_ROLE_KEY`.
   - Deploy:

```bash
supabase functions deploy send-notification --no-verify-jwt
```

Not: `database_webhook_setup.sql` DB trigger'ı, insert sonrası fonksiyonu tetikleyecek şekilde yapılandırılmıştır; production ortamda `anon` anahtarın public olmamasına dikkat edin — prod'da güvenlik için trigger'lar ve fonksiyon çağrıları uygun erişim seviyeleriyle yönetilmelidir.

---

**Testler**
- `test/` dizininde widget/unit test örnekleri var (örn. `widget_test.dart`). Unit ve integration test yazarken Supabase etkileşimleri için mock veya test DB kullanın.
- QA yönergelerine göre çevrimdışı senkronizasyon için Mock veritabanı ve mock connectivity senaryoları oluşturulmalı.

---

**Geliştirme Notları & Öneriler**
- RLS policies etkin durumda; fonksiyonlar ve backend çağrıları için doğru key/rol kullanıldığından emin olun.
- Edge Functions `FIREBASE_SERVICE_ACCOUNT_KEY` gizli tutulmalı; erişim izinleri sınırlandırılmalı.
- `sync_queue_service.dart` offline -> online flush mantığını dikkatle test edin; çakışma çözümü (conflict resolution) gerekiyorsa net bir strateji belirleyin.
- Bildirim testi için test kullanıcısında `profiles.fcm_token` alanı olmalı.
- `hive` box anahtarlarının versiyonlanması veya şema değişikliklerinde migration stratejisi düşünülmeli.

---

**Kaynak Koda Hızlı Referans (Seçilmiş dosyalar)**
- [pubspec.yaml](pubspec.yaml)
- [lib/main.dart](lib/main.dart)
- [lib/core/router/app_router.dart](lib/core/router/app_router.dart)
- [lib/core/services/sync_queue_service.dart](lib/core/services/sync_queue_service.dart)
- [lib/features/elevator/providers/elevator_providers.dart](lib/features/elevator/providers/elevator_providers.dart)
- [lib/features/elevator/views/elevator_detail_view.dart](lib/features/elevator/views/elevator_detail_view.dart)
- [supabase/migrations/](supabase/migrations)
- [supabase/functions/send-notification/index.ts](supabase/functions/send-notification/index.ts)
- [supabase/functions/_shared/fcm_v1.ts](supabase/functions/_shared/fcm_v1.ts)

---

## Uygulamanın Özellikleri (Features)

### 1. Elevator Management (Asansör Yönetimi)
**Dosya:** `lib/features/elevator/`  
**Amaç:** Asansör varlıklarını kaydetme, listeleme, detaylarını görüntüleme ve QR kod ile tanımlama.

**Ana İşlevler:**
- **Asansör Ekle**: Teknikçi yeni asansör bilgilerini (bina adresi, seri numarası, tür vs.) kaydedebilir.
- **Asansör Listele**: Pagination ile asansör listesi; cache sayesinde offline da çalışır.
- **Asansör Detay**: Seçili asansör hakkında tüm bilgiler ve bakım/arıza geçmişi.
- **QR Kod**: Her asansör için benzersiz QR kod oluşturma ve tarama desteği (mobile_scanner).
  - **QR Tarama Flow**: 
    - Scanner açılır (`/scan` route)
    - Teknikçi QR kodu tarıyor
    - **YENI**: Asansör detay yerine doğrudan `MaintenanceOperationView` açılıyor (`/maintenance/:elevatorId`)
    - Bakım formu hemen doldurulmaya başlanıyor
- **Status Tracking**: Asansör durumu (active/maintenance/inactive) takibi.

**State Management:**
- `elevatorListProvider` — pagination desteğiyle liste (AsyncNotifier)
- `elevatorsProvider` — tam asansör listesi (FutureProvider)
- `elevatorByIdProvider` — belirli asansör detayı (FutureProvider.family)
- `ElevatorCreateController` — yeni asansör oluşturma (AsyncNotifier)

**Veri Modeli:**
```dart
class ElevatorModel {
  final String id;
  final String? customerId;
  final String buildingName;
  final String? buildingAddress;
  final String serialNumber;
  final DateTime installationDate;
  final String status;
  final String? elevatorType;
  final int? capacity;
  // ...
}
```

---

### 2. Maintenance Management (Bakım Yönetimi)
**Dosya:** `lib/features/maintenance/`  
**Amaç:** Planlanan bakım görevlerini görüntüleme, bakım logu oluşturma ve tamamlanma işlemlerini yönetme.

**Ana İşlevler:**
- **Bakım Görevleri Görüntüleme**: Teknisyene atanan günlük/haftalık bakım planını görmek.
- **QR Tarama → Bakım Operasyon Sayfası** (YENİ):
  - Teknisyenin QR kodunu taraması sonrasında doğrudan `MaintenanceOperationView` açılır
  - Asansör bilgileri header olarak gösterilir (bina adı, adres, seri numara)
  - Bakım formunun tüm alanları aynı sayfada yer alır
- **Bakım Logu Oluşturma** (`MaintenanceOperationView`):
  - Bulunulan asansöre yönelik forma giriş
  - Muayene bulgularını yazma (multiline text)
  - Checklist items tamamlama (Dinamik kontrol listesi: Kabin ışığı, sensörler, frenler, yağlama, kuyu dibi, acil durum vb.)
  - Fotoğraf ekleme (kameradan çekme veya galeriden seçme)
    - Multiple photos desteği
    - Photo preview ve remove
  - Teknikçi imzası (signature paket ile draw)
  - Müşteri imzası (optional - checkbox "Müşteri imzası gerekli değil" seçeneği)
  - Offline mode: tüm veri lokalinde kaydedilir, sync queue'ya girer
  - Online mode: doğrudan Supabase'e yazılır
- **PDF Rapor**: Bakım logu PDF olarak oluşturma ve paylaşma
- **Bakım Tamamlanma**: Schedule status'u "completed" olarak işaretleme

**Special Features:**
- **Dedicated Maintenance Page**: Hızlı akış, tüm araçlar tek sayfada
- **Dual Signature Support**: Teknikçi ve müşteri tarafından imzalama (müşteri optional)
- **Checklist Verification**: Standart kontrol listesi (8 item) ile kalite güvence
- **Photo Evidence**: Fotoğraflar Supabase Storage'a yüklenir (URL kaydedilir)
- **Inspection Tracking**: Muayene geçmişi ve tarih-bazlı takibi
- **Offline Sync**: Yazma işlemleri offline da yapılabilir, reconnect'te otomatik senkronizasyon

**State Management:**
- `maintenanceRepositoryProvider` — DB operasyonları
- `maintenanceOperationElevatorProvider` — QR'dan gelen asansör verisi (FutureProvider.family)
- `maintenanceOperationControllerProvider` — bakım logu gönderme (AsyncNotifier)
- `pendingMaintenanceProvider` — onaylanmamış bakım logları
- `completedTodayCountProvider` — bugün tamamlanan bakım sayısı
- `logsByElevatorProvider` — belirli asansöre ait bakım loguları
- `MaintenanceController` — yeni bakım logu oluşturma (offline support)
- `MaintenanceCompletionController` — bakım tamamlanma işlemi

**Veri Modeli:**
```dart
class MaintenanceLogModel {
  final String id;
  final String? scheduleId;
  final String elevatorId;
  final String technicianId;
  final DateTime maintenanceDate;
  final String findings;
  final List<String>? photos; // Storage URLs
  final String? signatureUrl;     // Technician signature
  final String? customerSignatureUrl;
  final String? pdfUrl;           // Generated PDF report
  final bool isApproved;
  // ...
}

class ChecklistItemModel {
  final String id;
  final String maintenanceType;
  final String description;
  final bool isRequired;
  // ...
}
```

**Navigation Flow:**
```
Home View (Teknikçi)
    ↓
Scanner View (/scan)
    ↓
[QR kod tara]
    ↓
MaintenanceOperationView (/maintenance/:elevatorId) ← NEW
    ├─ Asansör başlığı
    ├─ Bulgular input
    ├─ Checklist (8 item)
    ├─ Fotoğraf upload
    ├─ Teknikçi imza
    ├─ Müşteri imza (optional)
    └─ Submit button
        ↓
    [Offline: Hive queue'ya, Online: Supabase'e]
        ↓
    Success snackbar → Home View geri
```

---

### 3. Fault Reporting (Arıza Takibi)
**Dosya:** `lib/features/fault/`  
**Amaç:** Asansörlerdeki arızaları raporlamak, izlemek ve çözmek.

**Ana İşlevler:**
- **Arıza Rapor Et**: Hızlı form ile asansörde tespit edilen arızayı rapor etme
  - Arıza tipi seçimi (Mekanik, Elektrik, Mahsur, Diğer)
  - Öncelik seviyesi (Düşük, Normal, Yüksek, Acil)
  - Detaylı açıklama
  - Fotoğraf ekleme (evidence)
  - Offline support
- **Arıza Listesi**: Tüm aktif arızalar veya asansör-bazlı arıza listesi
- **Arıza Detay**: Arıza hakkında tüm bilgiler, geçmiş ve çözüm notları
- **Durum Takibi**: open → in_progress → resolved

**State Management:**
- `faultRepositoryProvider` — DB operasyonları
- `activeFaultsProvider` — çözülmemiş arızalar
- `faultsByElevatorProvider` — belirli asansöra ait arızalar
- `faultByIdProvider` — belirli arıza detayı
- `FaultController` — arıza raporlama (offline support)

**Veri Modeli:**
```dart
class FaultReportModel {
  final String id;
  final String elevatorId;
  final String? reportedById;
  final DateTime reportedAt;
  final String description;
  final String? faultType;
  final String? priority; // Low, Medium, High, Critical
  final bool isResolved;
  final List<String>? faultImages; // Storage URLs
  final String? resolutionNotes;
  final DateTime? resolvedAt;
  // ...
}
```

---

### 4. Admin Dashboard (Yönetici Paneli)
**Dosya:** `lib/features/admin/`  
**Amaç:** Yöneticilerin tüm operasyonları (teknisyen, plan, asansör) kontrol etmesi.

**Ana İşlevler:**
- **Dashboard Ana Sayfası**:
  - Bugünün bakım özeti (tamamlanan, bekleyen, başarısız)
  - Aktif arızalar (priority bazında)
  - Teknisyen online/offline durumu
  - Günü ve haftayı kapsayan istatistikler
  
- **Teknisyen Yönetimi**:
  - Teknisyen listesi ve profil detayları
  - Role assign / revoke
  - Performans metrikleri (completed maintenance, response time)
  - Aktif/pasif durumu yönetimi
  
- **Plan Oluşturma** (Schedule):
  - Asansör-Teknisyen atanması
  - Bakım tarihi/saati belirleme
  - Bakım türü seçimi (Routine, Emergency, Inspection vs.)
  - Toplu atama / Tekil atama
  - Auto-assign (yakın teknisyenleri öneriş)
  
- **Master Calendar**:
  - Tüm asansörler için bakım takvimi
  - Tarih-bazında filtreleme
  - Teknisyen-bazında filtreleme
  - Conflict detection (aynı teknisyen çakışan görevler)
  
- **Harita Görünümü** (Map View):
  - Tüm asansörlerin konumunu harita üzerinde görüntüleme (flutter_map, latlong2)
  - Teknisyen lokasyonu tracking
  - Yakındaki asansör önerisi
  
- **Kullanıcı Yönetimi**:
  - Yeni kullanıcı oluşturma (email + password)
  - Role atama (admin, technician, customer)
  - Profil güncelleme
  - Deaktive / aktive etme
  
- **Asansör QR Export**:
  - Tüm asansörler için QR kodlarını toplu olarak oluşturma
  - PDF veya resim formatında export

**State Management:**
- `adminRepositoryProvider`, `scheduleRepositoryProvider`, `profileRepositoryProvider`
- `pendingSchedulesProvider` — bekleyen görevler
- `techniciansProvider` — teknisyen listesi
- `techniciansStatsProvider` — teknisyen performans metrikleri
- `scheduleCalendarProvider` — takvim verisi

---

### 5. Authentication (Kimlik Doğrulama)
**Dosya:** `lib/features/auth/`  
**Amaç:** Kullanıcı giriş ve oturum yönetimi.

**Ana İşlevler:**
- **Login**: Email + password ile Supabase auth
- **Logout**: Oturumu sonlandırma
- **Session Persistence**: Uygulama tekrar açıldığında otomatik session restore
- **Role-Based Access**: Kullanıcı rolüne göre görünüm/özellik kısıtlaması (RLS)
- **Forgot Password**: Email link ile şifre sıfırlama (opsiyonel)

**State Management:**
- `authRepositoryProvider` — Supabase auth operasyonları
- `currentUserProvider` — giriş yapan kullanıcı bilgisi
- `authStateProvider` — auth state (signed_in, signed_out)
- `AuthController` — login/logout (AsyncNotifier)

**Veri Modeli:**
```dart
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  // ...
}
```

---

### 6. Notifications (Bildirimler)
**Dosya:** `lib/features/notification/`  
**Amaç:** Firebase Cloud Messaging üzerinden push bildirimleri alıp göstermek ve geçmişini tutmak.

**Ana İşlevler:**
- **Push Bildirimi Alma**: Firebase Cloud Messaging ile background/foreground bildirim alıyor
  - Foreground: local notification ile göster
  - Background: silently handle ve sonra notification history'ye kaydet
  - Terminated state: initial message check
  
- **Bildirim İşleme**:
  - Bildirim üzerinden action (tapped): ilgili view'a navigate (deep link)
  - Bildirim data payload'ından route bilgisini oku
  
- **Notification History**: Kullanıcı tarafından alınan tüm bildirimler (isRead flag ile)
- **Mark as Read**: Kullanıcı bildirim detay açarsa "read" işaret

**Supabase Integration:**
- Yeni `maintenance_schedules` INSERT → DB trigger → Edge Function HTTP call
- Edge Function (`send-notification`):
  - User'ın `profiles.fcm_token`'ı alır
  - FCM HTTP v1 API ile push gönderir
  - Bildirim kaydı `notifications` tablosuna yazılır

**State Management:**
- `notificationRepositoryProvider` — DB bildirim fetch/update
- `notificationsProvider` — kullanıcının bildirim listesi
- `unreadCountProvider` — okunmamış bildirim sayısı

**Veri Modeli:**
```dart
class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final Map<String, dynamic>? dataPayload;
  final bool isRead;
  final DateTime createdAt;
  // ...
}
```

---

### 7. Offline & Sync (Çevrimdışı Mod ve Senkronizasyon)
**Dosya:** `lib/core/services/sync_queue_service.dart`, `read_cache_service.dart`  
**Amaç:** Kullanıcı çevrimdışı olsa bile yazma ve okuma işlemleri yapabilir.

**Ana İşlevler:**
- **Offline Write Queue**:
  - Yazma işlemleri (maintenance log, fault report, inspection update) Hive box'a kaydedilir
  - Timestamp + UUID ile sıralı şekilde
  - User reconnect'e kadar bekler
  
- **Auto Sync**:
  - `ConnectivityProvider` online durumunu dinler
  - `autoSyncProvider` tetiklenir
  - `SyncQueueService.flush()` queue'daki items'i sırasıyla Supabase'e gönderir
  
- **Conflict Resolution**:
  - Schedule ID varsa doğrudan update
  - Yoksa tarih + asansör + teknisyen bazında fuzzy match
  
- **Read Cache**:
  - Asansör listesi, bakım loguları Cache box'larında tutulur
  - Offline okuma mümkün
  - Periodically invalidate veya manual refresh
  
- **File Upload (Offline)**:
  - Fotoğraf, PDF, imza local storage'da kaydedilir
  - Sync sırasında Supabase Storage'a upload edilir
  - Storage URL DB'ye yazılır

---

---

## Uygulamada Yapılabilecek İşlemler (User Workflows)

Bu bölüm, her rol için uygulamada hangi işlemleri yapabileceğini açıklar.

### Role-Based Capabilities (Rol Bazında Yetenekler)

#### 👨‍🔧 **TECHNICIAN** (Teknikçi)
Gönüllü olarak asansör bakım ve arıza raporlama yapan kullanıcılar.

**Ana Workflow'lar:**

1. **Günlük Görevleri Görüntüleme**
   - Home View açıldığında: "Bugünün Planı" / "My Schedule" sekmesi
   - Bugüne atanan tüm bakım görevlerini tarihe göre listelemek
   - Her görev için: asansör adresi, tür, atanma saati, durum (pending/in_progress)
   - Gerçekleştirilen bakım sayısını görmek ("3 tamamlandı bugün")
   - Çevrimdışı mod: görevleri görmek mümkün (cache'den)

2. **Asansör Taraması (QR Kod) → Doğrudan Bakım Sayfası**
   - "Scanner" butonu → kamera açılır
   - QR kod tarar
   - **YENİ**: `MaintenanceOperationView` açılır (`/maintenance/:elevatorId`)
   - Asansör bilgileri başlıkta gösterilir
   - Bakım formunu hemen doldurmaya başlar

3. **Bakım Logu Oluşturma (Offline-friendly) — `MaintenanceOperationView`**
   - Asansör başlığında bilgiler gösterilir (bina adı, adres, seri numara)
   - Form doldurma:
     - Muayene bulgularını yazma
     - Checklist items'ı tik atma (8 standart kontrol)
     - Fotoğraf çekme/ekleme (camera, gallery, multiple)
     - Teknikçi imzası çizme (signature paket)
   - Müşteri İmzası (müşteri varsa):
     - Müşteri imzası alanı (tablet vs. üzerinde müşteri çizer)
     - "Müşteri imzası gerekli değil" → checkbox işaretle
   - Gönder:
     - İnternet varsa: doğrudan Supabase'e kaydedilir + notification gönderilir
     - İnternet yoksa: Hive queue'ya kaydedilir + "Beklemede" gösterilir
   - İş tamamlanır → Schedule status "completed" olur
   - Success snackbar → Home View'a geri

4. **Arıza Raporlama**
   - Asansörde bir sorun tespit ederlerse: "Arıza Rapor Et" butonu
   - Form:
     - Arıza tipi (electrical, mechanical, control_system, safety_system vb.)
     - Öncelik (Low, Medium, High, Critical)
     - Detaylı açıklama
     - Fotoğraf (kanıt)
   - Gönder:
     - Admin'e otomatik bildirim gider
     - Offline da yapılabilir
   - Arıza takibi: "My Reported Faults" sekmesinde durumu izlemek

5. **İnceleme / Muayene Güncellemesi**
   - Periyodik muayene görevleri varsa: inspection status güncellemek
   - Kontrol listesini doldurup fotoğraf ve imza eklemek
   - Durum: "pending" → "completed"

6. **Geçmiş Bakım Logu Görüntüleme**
   - "Bakım Geçmişi" / "Maintenance History" 
   - Asansör seçip geçmişini görmek
   - Her log için: tarih, durum, bulgular, fotoğraf, PDF
   - PDF indirme/paylaşma

7. **Profil Yönetimi**
   - Profilini açıp kişisel bilgilerini görüntülemek
   - Name, phone, email vs.
   - Performance metrics (bu ay tamamlanan bakım sayısı, average response time)

8. **Çevrimdışı Mod Desteği**
   - Internet kesilse bile:
     - Atanan görevleri görüntüleyebilir
     - Bakım logu doldurabilir
     - Fotoğraf/imza ekleyebilir
     - "Gönder" basıldığında → sync queue'ya kaydedilir
   - İnternet geldiğinde:
     - Offline banner kaybolur
     - Auto-sync başlar
     - Sıralı şekilde tüm işlemler Supabase'e gönderilir
     - Success/fail notification gösterilir

---

#### 👨‍💼 **ADMIN** (Yönetici)
Tüm operasyonları planlayan ve takip eden kullanıcılar.

**Ana Workflow'lar:**

1. **Dashboard (Ana Görünüm)**
   - Birleştirilmiş özet:
     - "Bugün: 3 tamamlandı, 5 beklemede, 1 arıza"
     - Kritik arızalar (High/Critical) - kırmızı vurgu
     - Son 24 saatte en etkin 3 teknisyen
     - Gemileri çevrimdışı teknisyenler
   - Quick action butonları:
     - "Yeni Görev Oluştur"
     - "Asansör Ekle"
     - "Teknisyen Ata"
     - "Arızaları Gör"

2. **Bakım Görevleri Planlama (Schedule)**
   - "Planlama" / "Scheduling" sayfası
   - Görev oluşturma:
     - Asansör seçimi (dropdown)
     - Teknikçi seçimi (dropdown)
     - Tarih/saat belirleme (date picker + time picker)
     - Bakım türü (Routine, Emergency, Inspection, Safety Inspection)
     - Notlar (özel isteği varsa)
     - Oluştur → Teknisyene bildirim gider
   - Toplu atama:
     - CSV upload veya liste paste
     - Sistem: "Pazartesi günü A,B,C asansörlerine bakım yap" gibi görevleri parse eder
   - Conflict detection:
     - "Teknisyen X zaten 10:00-10:30 arasında görev var" uyarısı
   - Görev düzenleme/silme

3. **Master Takvim (Full Calendar)**
   - Ay/hafta/gün görünümü
   - Tüm asansörler ve tüm teknisyenlerin görevlerini birlikte görme
   - Renk kodlama:
     - Yeşil = tamamlandı
     - Sarı = devam ediyor
     - Kırmızı = gecikmiş
     - Gri = iptal
   - Drag-and-drop (opsiyonel): görev tarihini değiştirme
   - Filtre: teknisyen, asansör, status, tip

4. **Harita Görünümü**
   - Tüm asansörlerin konum bilgisini harita üzerinde görmek
   - Renkler: operasyon durumunu belirtir (aktif/bakımda/arıza)
   - Markerler: klik → asansör detay + planlanmış görevler
   - Teknisyen real-time location (opsiyonel, varsa)
   - Search: adres gibi arasılır

5. **Teknisyen Yönetimi**
   - Teknisyen listesi: tüm aktif teknisyenleri görme
   - Her teknisyen'in:
     - Profil bilgileri (ad, telefon, email)
     - Bu ay tamamlanan görev sayısı
     - Ortalama işlem süresi
     - Puanlama (customer satisfaction)
     - Online/offline durumu
   - Aksiyon:
     - Rol atama (technician → admin yükseltme vs.)
     - Durum değiştirme (active → inactive)
     - Şifresi sıfırlama linki gönderme
     - Profil düzenleme

6. **Kullanıcı Yönetimi**
   - Tüm kullanıcılar listesi (teknisyen, yönetici, müşteri)
   - Yeni kullanıcı oluşturma:
     - Email ve password belirleme
     - Role seçimi
     - Gönder → kullanıcı email'de activate linki alır
   - Kullanıcı düzenleme:
     - Email, rol, durum
   - Deaktive/aktive etme
   - Şifre reset linki gönderme

7. **Asansör Yönetimi**
   - Asansör listesi: tüm asansörler
   - Her asansör için:
     - Bina adresi, seri numarası, tip
     - Kurulum tarihi, son bakım tarihi
     - Status (active, maintenance, inactive)
     - Planlanan sonraki bakım tarihi
   - Yeni asansör ekleme:
     - Form: bina adı, adres, seri numara, tür, kurulum tarihi
     - Lat/long (harita tıklanarak girilir)
     - Oluştur → otomatik QR kod generate
   - Asansör detay:
     - Tüm bakım loguları
     - Arıza geçmişi
     - Bakım takvimi
     - Fotoğraf galerisi
   - Asansör düzenleme/silme

8. **QR Kodları Yönetme**
   - Tüm asansörler için QR kodlarını toplu olarak oluşturma
   - PDF olarak export (yapılacak liste şeklinde):
     - QR kod + asansör bilgileri (ad, seri numara)
     - Baskı için optimize edilmiş
   - Baskı → teknisyenler alır

9. **Bildirimler & Loglar**
   - Sent notifications: gönderilen bildirimler listesi
     - Kime, ne zaman, ne, status
   - Activity log: system log'ları
     - "Teknisyen X, asansör Y'de bakım logu oluşturdu"
     - "Yönetici Z, teknisyen A'yı deaktive etti"

10. **Raporlar**
    - Aylık bakım özeti
    - Arıza frequency analizi
    - Teknisyen performance rankı
    - Asansör reliability (uptime %)
    - Export: CSV, PDF

11. **Bekleyen Bakım Loguları Onaylama**
    - Teknisyen'in oluşturduğu loglar "pending" durumunda gelir
    - Admin onaylar:
      - Bilgileri kontrol eder
      - Fotoğraf/bulgular yeterli mi?
      - PDF içeriğini görüntüler
      - İmzalar var mı?
    - Onay → "approved", müşteriye email vs.
    - Red → "rejected" + not ekleyip teknikçiye geri gönder

---

#### 👨 **CUSTOMER** (Müşteri - opsiyonel web dashboard)
Binası sahibi veya facility manager.

**Ana Workflow'lar:**

1. **Asansör Listesi Görüntüleme**
   - Kendi binasındaki asansörleri listeleme
   - Durum görmek: "aktif", "bakımda", "arıza"

2. **Bakım Logu Görüntüleme**
   - Asansör seçip bakım geçmişi görmek
   - Her log için: tarih, bulgular, fotoğraf, PDF raporu indirme

3. **İş Planı Görüntüleme**
   - Upcoming maintenance schedule görmek
   - "Pazartesi 10:00'da asansör #1 bakımı yapılacak"

4. **Arıza Raporları**
   - Açık arızaları görmek
   - Status izlemek: "open" → "in_progress" → "resolved"

---

### End-User Use Cases (Senaryolar)

#### Senaryo 1: Rutine Bakım (Teknikçi - Online)
```
1. Teknikçi uygulamayı açıyor
2. Home View → "Bugünün Görevleri" sekmesinde 5 bakım var
3. 10:00'daki görev seçiliyor
4. Asansör adresi görülüyor: "Caddebostan, Apt #5"
5. Scanner icon'a basıyor veya QR'ı manuel olarak tarıyor
6. [QR tarama]
7. MaintenanceOperationView açılıyor (asansör başlığı + form)
8. Checklist items'ı tik atıyor (kablo, kapı, güvenlik, etc.)
9. Fotoğraf çekiyor (3 fotoğraf)
10. Bulgularını yazıyor
11. Teknikçi imzası çiziyor
12. Müşteri mevcut → müşteri imzası çiziyor
13. "Bakım Logu Gönder" → Supabase'e kaydedilir
14. "✓ Bakım logu kaydedildi" snackbar
15. Home View'a dönüyor
16. Müşteri'ye bildirim: "Asansörünüz bakımı tamamlandı"
```

#### Senaryo 2: Offline Arıza Raporlama (Teknikçi - Offline)
```
1. Teknikçi interneti olmayan bir binada
2. Asansörde arıza tespit ediyor
3. "Arıza Rapor Et" basıyor
4. Form doldurması:
   - Arıza tipi: "Electrical - Kapı sensörü bozuk"
   - Öncelik: "High"
   - Fotoğraf çekiyor
5. "Gönder" → "✓ Offline kaydedildi. İnternet gelince senkron olacak"
6. Sync badge gösterilir (orange "↻" ikon + "1 beklemede")
7. [Teknikçi başka lokasyona gidiyor, WiFi'a bağlanıyor]
8. Auto-sync başlıyor
9. Arıza raporu Supabase'e gidiyor
10. Admin'e bildirim gidiyor
11. "✓ Senkron tamamlandı"
```

#### Senaryo 3: Toplu Görevi Planlama (Admin)
```
1. Admin "Planlama" sekmesini açıyor
2. "Toplu İşlem" buton
3. CSV file upload: "asansor_id, gun, saat"
4. 20 görev parse ediliyor
5. Conflict check: 2 çakışma tespit ediliyor → warning
6. Admin çakışmaları çözdükten sonra "Kaydet" basıyor
7. Sistem 20 görevi oluşturuyor
8. 20 teknikçiye bildirim gidiyor ("Yeni görev atandı")
9. Dashboard'da güncellenmiş sayılar görülüyor
```

#### Senaryo 4: Harita Üzerinde Asansör Takibi (Admin)
```
1. Admin "Harita" sekmesini açıyor
2. 50 asansör harita üzerinde gösterilir
3. Yeşil marker: aktif, Sarı: bakımda, Kırmızı: arızada
4. Kırmızı markerlerden birine tıklıyor
5. Popup: "Asansör #12, Caddebostan, ARIZA: Kapı sensörü"
6. "Detay" linki → asansör view → arıza raporı
7. Hızlı atama: "Teknikçi Ahmet'i ata" buton
8. Form: tarih/saat → Ahmet'e bildirim gidiyor
```

#### Senaryo 5: Aylık Raporlama (Admin)
```
1. Admin "Raporlar" sekmesini açıyor
2. "Nisan 2026 Özeti" raporu generate ediyor
3. PDF oluşturulur:
   - 150 görev planlandı, 148 tamamlandı, 2 iptal
   - En etkin 5 teknikçi rankı
   - 5 kritik arıza → hepsi çözüldü
   - Asansör #3 en çok bakım alıyor (frequency analizi)
4. Raporun exportu: PDF + Excel
5. Müşteri/üst yöneticiye e-posta ile gönderebilir
```

---

### Sunulan Hizmetler (Service Value)

**Teknikçi için:**
- ✅ Günlük görevler otomatik atanıyor (manuel arama yok)
- ✅ Çevrimdışı çalışma (internet bağlantısı kesilse bile veri kaybı yok)
- ✅ Otomatik senkronizasyon (reconnect'te veriler otomatik gider)
- ✅ Hızlı veri girişi (form + checklist + fotoğraf + imza)
- ✅ Raporlar otomatik PDF'e dönüştürülüyor
- ✅ Müşteriye anında bildirim (iş bitince "tamamlandı" haber alıyor)
- ✅ Kişisel performans metrikleri (benchmark vs diğer teknisyenler)

**Admin için:**
- ✅ Operasyonal görünürlük (tüm görevler, tüm teknisyenler, gerçek zamanlı status)
- ✅ Akıllı planlama (toplu atama, conflict detection, auto-assign önerileri)
- ✅ Harita tabanlı yönetim (coğrafi görselleştirme)
- ✅ Analitik & raporlama (trend, performance, reliability)
- ✅ Bildirim otomasyonu (görev atanınca, arıza rapor edilince otomatik haber)
- ✅ Veri kalitesi (checklist, imza, fotoğraf → konsisten, auditble logs)
- ✅ Compliance & traceability (her bakım işi tamamen dokümante)

**Müşteri için:**
- ✅ Şeffaflık (bakım tarihleri, technisyen, bulgular)
- ✅ PDF raporlar (arşivleme, sigorta vs. için)
- ✅ Arıza takibi (açık arıza varsa bilir, ne zaman çözüleceğini bilir)
- ✅ Bildirimler (yeni görev, arıza update, tamamlama)

**Sistem için:**
- ✅ Ölçeklenebilir (cloud-based, unlimited asansör/teknikçi)
- ✅ Güvenli (RLS policies, encrypted connections)
- ✅ Hızlı (realtime updates, push notifications)
- ✅ Güvenilir (offline-first, automatic sync, retry logic)
- ✅ Entegrasyonlu (FCM, Supabase, Storage, Edge Functions)

---



**Ana Tablolar ve Alanlar:**

| Tablo | Amaç | Önemli Alanlar |
|-------|------|-----------------|
| `profiles` | Kullanıcı profilleri (teknikçi, yönetici, müşteri) | `id`, `user_id`, `role`, `fcm_token`, `full_name`, `phone` |
| `elevators` | Asansör varlıkları | `id`, `customer_id`, `building_address`, `serial_number`, `installation_date`, `status` |
| `maintenance_schedules` | Planlanan bakım görevleri | `id`, `elevator_id`, `technician_id`, `scheduled_date`, `status` (pending/in_progress/completed), `maintenance_type` |
| `maintenance_logs` | Tamamlanan bakım kayıtları | `id`, `schedule_id`, `technician_id`, `maintenance_date`, `findings`, `photos` (array), `signature_url`, `customer_signature_url`, `pdf_url` |
| `faults` | Arıza raporları | `id`, `elevator_id`, `technician_id`, `reported_at`, `fault_type`, `priority`, `status`, `resolution_notes`, `fault_images` (array) |
| `inspection_history` | Muayene tarihi | `id`, `elevator_id`, `scheduled_date`, `inspection_date`, `inspector_id`, `findings`, `status` |
| `notifications` | Push bildirimleri | `id`, `user_id`, `title`, `body`, `data_payload` (JSONB), `is_read`, `created_at` |

**RLS (Row Level Security) Politikaları:**
- Teknikçi: sadece kendisine atanan görevleri ve asansörları görebilir.
- Admin: tüm görevleri, asansörları ve teknisyenleri yönetebilir.
- Müşteri: sadece kendi asansörlerini ve bakım logu özetini görebilir.

---

## Ek 2: Auth Flow ve Navigation Diyagramı

```
┌─────────────────────────────────────────────────────────────┐
│                       App Launch                            │
├─────────────────────────────────────────────────────────────┤
│ 1. Firebase init                                             │
│ 2. Supabase init                                             │
│ 3. Hive boxes open (sync queue, cache)                       │
│ 4. NotificationService start                                 │
│ 5. GoRouter checks auth state                                │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   v
        ┌──────────────────────┐
        │ Auth State Change?   │
        └──────┬───────────────┘
               │
         ┌─────┴──────┐
         │            │
    YES  v            v  NO
  ┌────────────┐  ┌──────────────────┐
  │ Signed In  │  │ Not Signed In     │
  └─────┬──────┘  └─────┬────────────┘
        │              │
        v              v
   ┌─────────────┐  ┌──────────────┐
   │ Home View   │  │ Login View    │
   │ (Riverpod:  │  │ (auth flow)   │
   │ fetch user  │  └──────────────┘
   │ profile)    │
   └────────────┘
   
GoRouter redirect() fonksiyonu:
  • Supabase.instance.client.auth.currentUser kontrol et
  • User null ise → Login View'e yönlendir
  • User varsa + role check → Home/Admin View'e yönlendir
```

**Bildirim Flow:**
```
1. Maintenance Schedule INSERT
   ↓
2. DB Trigger (notify_technician_on_assignment)
   ↓
3. Edge Function HTTP POST (send-notification)
   ↓
4. FCM HTTP v1 API (OAuth2 service account)
   ↓
5. Notification saved to notifications table
   ↓
6. Flutter app receives message (FirebaseMessaging.onMessage)
   ↓
7. NotificationService displays local notification
   ↓
8. User taps → Navigation to assigned task
```

---

## Ek 3: Offline Senkronizasyon Mekanizması (Detaylı)

**Temel Konsept:**
- Kullanıcı internet bağlantısı olmadığında yazma işlemleri yerel `Hive` kutusunda (`syncQueueBox`) sırayla saklanır.
- Bağlantı geri geldiğinde `SyncQueueService.flush()` çağrılır ve items sırasıyla Supabase'e gönderilir.

**Sync Senaryosu:**

```
SCENARIO: Offline Maintenance Log Entry
─────────────────────────────────────────
1. Teknikçi çevrimdışı (connectivity_plus.Connected = false)
2. Bakım formu doldurur (fotoğraf, imza vs. local file olarak kaydedilir)
3. "Save" basıyor
   → SyncQueueService.enqueue(
       type: 'maintenance_log',
       payload: { photos: ['/local/path'], signature: '...' }
     )
   → Hive box'a JSON olarak kaydedilir
   → Riverpod listener (pendingSyncCountProvider) → UI update
4. [Internet geri geliyor]
5. ConnectivityProvider state değişiyor
6. Main.dart'da ref.watch(autoSyncProvider) tetikleniyor
   → SyncQueueService.flush(Supabase.instance.client)
7. Her item için:
   a) Fotoğraf local path'ten Supabase Storage'a upload
   b) İmza base64 → PNG → Storage'a upload
   c) maintenance_logs table'a INSERT
   d) maintenance_schedules status → 'completed'
   e) Eğer başarılı → Hive box'dan sil
   f) Eğer hata → Hive'da tut (retry)

Result: Teknisyen offline olsa bile veriler kaybedilmez,
        bağlantı gelince otomatik senkron olur.
```

**Sync Queue Service İç İşleyişi:**
- Dequeue format (JSON):
```json
{
  "id": "16c8a2b5_<uuid>",
  "type": "maintenance_log",
  "payload": { "elevator_id": "...", "photos": [...] },
  "queued_at": "2026-05-11T10:30:00Z"
}
```

- Flush sırası: key'ler lexicographic (timestamp prefix) olarak sort edilir → FIFO.
- Conflict resolution: `schedule_id` varsa doğrudan update; yoksa date-based matching.

**Read Cache (Offline Okuma):**
- Her `elevators` fetch'i sonrası Hive `elevatorsCacheBoxName` box'ına kaydedilir.
- Offline modda: `read_cache_service.dart` cache'den veri döner.
- TTL (time-to-live): Opsiyonel; cache genelde manuel invalidate edilir veya app restart'ta silinir.

---

## Ek 4: Riverpod Provider Architecture

**Provider Katmanları:**

```
┌──────────────────────────────────┐
│ UI Layer (Views / Screens)       │
└────────────┬─────────────────────┘
             │
             v
┌──────────────────────────────────┐
│ Riverpod Providers               │
│ - StateNotifierProvider          │
│ - FutureProvider (async fetch)   │
│ - StreamProvider (listen)        │
│ - ValueNotifier → Provider       │
└────────────┬─────────────────────┘
             │
             v
┌──────────────────────────────────┐
│ Repositories (Data Layer)        │
│ - elevator_repository.dart       │
│ - maintenance_repository.dart    │
│ - auth_repository.dart           │
└────────────┬─────────────────────┘
             │
             v
┌──────────────────────────────────┐
│ Services & API Layer             │
│ - Supabase Client                │
│ - Firebase                       │
│ - Sync Queue Service             │
│ - Read Cache Service             │
└──────────────────────────────────┘
```

**Örnek Provider Pattern (Elevator):**

```dart
// elevator_providers.dart

// FutureProvider: bir asansör ID ile veri fetch et
final elevatorDetailsProvider = FutureProvider.family<ElevatorModel, String>(
  (ref, elevatorId) async {
    final repo = ref.watch(elevatorRepositoryProvider);
    return repo.getElevatorDetail(elevatorId);
  },
);

// StateNotifierProvider: asansör listesi state'ını tutmak
final elevatorListProvider = StateNotifierProvider<
    ElevatorListNotifier,
    AsyncValue<List<ElevatorModel>>
>((ref) {
  final repo = ref.watch(elevatorRepositoryProvider);
  return ElevatorListNotifier(repo);
});

// StreamProvider: Supabase realtime subscription
final elevatorStreamProvider = StreamProvider<List<ElevatorModel>>(
  (ref) {
    final repo = ref.watch(elevatorRepositoryProvider);
    return repo.streamElevators();
  },
);

// Auto-sync provider (global — main.dart'da watch'ler)
final autoSyncProvider = FutureProvider<void>((ref) async {
  final connectivity = ref.watch(connectivityStatusProvider);
  if (connectivity == ConnectivityStatus.connected) {
    final syncService = ref.watch(syncQueueServiceProvider);
    await syncService.flush(Supabase.instance.client);
  }
});
```

**Best Practice:**
- `FutureProvider.family` → tek öğe fetch (elevator detail vs.).
- `StateNotifierProvider` → mutable state + business logic.
- `StreamProvider` → realtime updates (Supabase subscriptions).
- `watchProvider` global app state'i için (connectivity, sync status).

---

## Ek 5: CI/CD Pipeline (GitHub Actions Örneği)

**Dosya: `.github/workflows/flutter-release.yml`**

```yaml
name: Flutter Release Build

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.11.4'
      
      - name: Load Firebase Options
        run: |
          echo "${{ secrets.FIREBASE_SERVICE_KEY }}" > lib/firebase_options.dart
      
      - name: Get dependencies
        run: flutter pub get
      
      - name: Build APK
        run: flutter build apk --release
      
      - name: Upload to Play Store
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJson: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
          packageName: com.asansor.app
          releaseFiles: build/app/outputs/apk/release/*.apk
          track: production

  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.11.4'
      
      - name: Get dependencies
        run: flutter pub get
      
      - name: Build iOS
        run: flutter build ios --release
      
      - name: Deploy to TestFlight
        uses: Apple-Actions/upload-testflight-build@v1
        with:
          app-path: build/ios/ipa/*.ipa
          issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
          api-key-id: ${{ secrets.APPSTORE_API_KEY_ID }}
          api-private-key: ${{ secrets.APPSTORE_API_PRIVATE_KEY }}

  supabase-migrate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Supabase CLI
        run: npm install -g supabase
      
      - name: Run migrations
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
        run: |
          supabase link --project-ref ${{ secrets.SUPABASE_PROJECT_ID }}
          supabase migration up
      
      - name: Deploy Edge Functions
        run: |
          supabase functions deploy send-notification --no-verify-jwt
          supabase functions deploy notify-technician --no-verify-jwt

  tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.11.4'
      
      - name: Get dependencies
        run: flutter pub get
      
      - name: Run tests
        run: flutter test --coverage
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
```

**Secrets (GitHub → Settings → Secrets):**
- `FIREBASE_SERVICE_KEY` → Firebase service account JSON
- `GOOGLE_PLAY_SERVICE_ACCOUNT` → Google Play JSON key
- `APPSTORE_ISSUER_ID`, `APPSTORE_API_KEY_ID`, `APPSTORE_API_PRIVATE_KEY` → App Store Connect
- `SUPABASE_ACCESS_TOKEN` → Supabase CLI token
- `SUPABASE_PROJECT_ID` → Project ref

**Release Prosedürü:**
```bash
# Tag oluştur
git tag v1.0.0
git push origin v1.0.0

# GitHub Actions otomatik başlar → build → test → deploy
```

---

## Ek 6: Hata Ayıklama ve Troubleshooting

**Yaygın Sorunlar:**

| Sorun | Çözüm |
|-------|-------|
| "FCM token not registered" | `profiles.fcm_token` null mu? Firebase messaging initialize ettiniz mi? |
| Offline yazma başarısız olmadı ama senkron etmiyor | `connectivity_plus` durumu kontrol et; `autoSyncProvider` çalışıyor mu? |
| Bildirim alınmıyor | Edge Function logs'u kontrol et; `FIREBASE_SERVICE_ACCOUNT_KEY` set mi? |
| Supabase RLS error | Auth token doğru mu? User role database'de var mı? |
| Hive box "is already open" | App multiple kez başlatıldı mı? (test sırasında) |

**Debug Mode Commands:**
```bash
# FCM token print
flutter run --verbose | grep "FCM TOKEN"

# Hive box içeriğini kontrol et (emulator)
adb shell "sqlite3 /data/data/com.asansor.app/databases/hive_box.db"

# Supabase Edge Function logs
supabase functions logs send-notification

# Supabase RLS policy test
curl -X GET https://<project>.supabase.co/rest/v1/maintenance_schedules \
  -H "Authorization: Bearer <token>" \
  -H "apikey: <anon-key>"
```

---

Sonuç: Uygulama offline-first, push-notification-heavy bir uygulamadır; sync queue ve caching mekanizmalarının iyice test edilmesi önemlidir. Tüm teknisyen operasyonları (maintenance log, fault report) offline desteği ile yapılabilir; admin dashboard web'de olabilir.

---

## Ek 7: Proje Kaynak Kod Rehberi

Aşağıda projedeki tüm önemli kaynak kod dosyaları ve üstlendikleri görevler listelenmiştir.

### 1. Uygulama Giriş ve Konfigürasyon
- **[main.dart](lib/main.dart)**: Uygulamanın giriş noktası. Servislerin (Firebase, Supabase, Hive, Notifications) başlatılması, hata yakalama (Error Handling) kurulumu ve ana uygulama widget'ı.
- **[firebase_options.dart](lib/firebase_options.dart)**: Firebase projesi için platforma özel konfigürasyon ayarları.
- **[pubspec.yaml](pubspec.yaml)**: Proje bağımlılıkları, varlıklar (assets) ve genel proje tanımı.

### 2. Core (Çekirdek Yapı)
- **lib/core/constants/**
  - **[supabase_constants.dart](lib/core/constants/supabase_constants.dart)**: Supabase URL ve Anon Key gibi sabitlerin tutulduğu dosya.
- **lib/core/exceptions/**
  - **[app_exception.dart](lib/core/exceptions/app_exception.dart)**: Uygulama genelinde kullanılan özel hata sınıfları.
- **lib/core/models/**
  - **[paginated_state.dart](lib/core/models/paginated_state.dart)**: Sayfalamalı (pagination) veriler için genel durum yönetimi modeli.
- **lib/core/providers/**
  - **[connectivity_providers.dart](lib/core/providers/connectivity_providers.dart)**: İnternet bağlantı durumunu takip eden Riverpod provider'ları.
- **lib/core/router/**
  - **[app_router.dart](lib/core/router/app_router.dart)**: GoRouter yapılandırması, rotalar ve kimlik doğrulama durumuna göre yönlendirme (redirect) mantığı.
- **lib/core/services/**
  - **[auto_schedule_service.dart](lib/core/services/auto_schedule_service.dart)**: Periyodik bakımların otomatik planlanmasını sağlayan servis.
  - **[notification_service.dart](lib/core/services/notification_service.dart)**: Push bildirimleri ve yerel bildirimlerin yönetimi.
  - **[pdf_service.dart](lib/core/services/pdf_service.dart)**: Bakım ve muayene raporlarının PDF formatında oluşturulması.
  - **[read_cache_service.dart](lib/core/services/read_cache_service.dart)**: Hive kullanarak verilerin çevrimdışı okunabilmesi için önbellekleme.
  - **[storage_service.dart](lib/core/services/storage_service.dart)**: Supabase Storage dosya yükleme ve yönetimi.
  - **[sync_queue_service.dart](lib/core/services/sync_queue_service.dart)**: Çevrimdışı yapılan işlemlerin (yazma) sıraya alınması ve internet geldiğinde senkronize edilmesi.
- **lib/core/theme/**
  - **[app_colors.dart](lib/core/theme/app_colors.dart)**: Uygulamanın renk paleti ve tema tanımları.
- **lib/core/utils/**
  - **[error_handler.dart](lib/core/utils/error_handler.dart)**: Global hata yönetimi ve loglama yardımcıları.
- **lib/core/widgets/**
  - **[error_boundary.dart](lib/core/widgets/error_boundary.dart)**: Beklenmedik UI hatalarını yakalayan ve kullanıcıya hata ekranı gösteren widget.
  - **[offline_banner.dart](lib/core/widgets/offline_banner.dart)**: İnternet bağlantısı koptuğunda üstte görünen bilgilendirme bandı.

### 3. Özellikler (Features)

#### Admin (Yönetici Paneli)
- **models/**: `profile_model.dart`, `schedule_model.dart`, `technician_stats.dart` vb. modeller.
- **providers/**: Yönetici dashboard ve takvim verilerini sağlayan provider'lar.
- **repositories/**: Admin görevleri (kullanıcı yönetimi, atama) için veritabanı erişimi.
- **views/**: Dashboard, Harita, Takvim, QR oluşturma ve kullanıcı yönetimi ekranları.

#### Auth (Kimlik Doğrulama)
- **providers/auth_providers.dart**: Giriş yapan kullanıcı ve oturum durumu yönetimi.
- **repositories/auth_repository.dart**: Supabase Auth işlemleri (login, logout).
- **views/login_view.dart**: Giriş yapma ekranı.

#### Elevator (Asansör Yönetimi)
- **models/elevator_model.dart**: Asansör veri modeli.
- **presentation/widgets/**: Muayene durumu göstergeleri (badge) ve form sayfaları.
- **providers/**: Asansör listesi, detayı ve muayene güncellemeleri için kontrolcüler.
- **repositories/elevator_repository.dart**: Asansör verilerine erişim katmanı.
- **views/**: Asansör listesi, detayları, yeni asansör ekleme ve QR tarama ekranları.

#### Fault (Arıza Takibi)
- **models/fault_report_model.dart**: Arıza bildirim modeli.
- **providers/fault_providers.dart**: Aktif arızaları listeleyen ve yöneten provider'lar.
- **repositories/fault_repository.dart**: Arıza veritabanı işlemleri.
- **views/fault_detail_view.dart**: Arıza detay ve çözüm ekranı.

#### Maintenance (Bakım İşlemleri)
- **models/**: Bakım logları ve kontrol listesi (checklist) modelleri.
- **presentation/**: Bakım yapma (`MaintenanceOperationView`) ve tamamlama ekranları.
- **providers/**: Bakım süreci yönetimi ve veri gönderme kontrolcüleri.
- **repositories/**: Bakım logları ve checklist maddeleri için veritabanı işlemleri.

#### Notification (Bildirim Geçmişi)
- **models/notification_model.dart**: Bildirim veri modeli.
- **presentation/notification_history_screen.dart**: Kullanıcıya gelen geçmiş bildirimlerin listesi.
- **providers/notification_providers.dart**: Bildirim listesini ve okunmamış sayısını yöneten provider'lar.

### 4. Supabase (Backend & Veritabanı)
- **supabase/migrations/**: Veritabanı şemasını (tablolar, trigger'lar, RLS politikaları) tanımlayan SQL dosyaları.
- **supabase/functions/**:
  - **send-notification/**: FCM kullanarak bildirim gönderen ana Edge Function.
  - **_shared/fcm_v1.ts**: FCM HTTP v1 API için yardımcı kodlar.
- **supabase/database_webhook_setup.sql**: Veritabanı değişikliklerinde Edge Function tetikleyen SQL kurulumu.

### 5. Testler
- **test/widget_test.dart**: Temel widget testleri.
- **test/core/services/**: `notification_service_test.dart`, `sync_queue_service_test.dart` gibi kritik servislerin testleri.

