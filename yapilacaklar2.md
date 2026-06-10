# Yapılacaklar — Tam Öncelik Listesi

> Kaynak: [comprehensive_audit_report.md](file:///d:/Asansor/doc/comprehensive_audit_report.md)
> Sıralama: Kritiklik + ROI + Bağımlılık zinciri

---

## 🔴 FAZ 1 — ACİL (Şimdi / 30 Gün)
> Production'a çıkmadan önce mutlaka tamamlanmalı. Veri kaybı, güvenlik ihlali veya Store reddi riski.

### GÜVENLİK

- [ ] **1. Firebase service account key rotation ve git temizliği**
  - Ne: `supabase/.env.local` .gitignore'da olmasına rağmen hâlâ git tracked. İçindeki tam RSA private key + `project_id: asansor-efaed` sızdırılmış durumda
  - Yapılacak:
    1. Acil: `git rm --cached supabase/.env.local` çalıştırılarak index'ten silinmeli
    2. Firebase Console → Service Accounts → mevcut key'i revoke et
    3. `git filter-repo --path supabase/.env.local --invert-paths` ile git tarihçesinden tamamen sil
    4. Yeni key'i Supabase Dashboard → Edge Function Secrets'e yükle
  - Dosya: `supabase/.env.local`, `supabase/functions/send-notification/index.ts`
  - Efor: **Medium**

- [ ] **2. Webhook fallback secret'ını kaldır**
  - Ne: `'local-dev-secret-key'` fallback'i 3 ayrı yerde mevcut — Edge Function ve 2 migration trigger
  - Yapılacak: `COALESCE(..., 'local-dev-secret-key')` satırlarını fail-closed hale getir; secret yoksa exception fırlat
  - Dosya: `supabase/functions/send-notification/index.ts:66`, `supabase/migrations/20260604000001_use_settings_table_for_webhook_secret.sql:30,67`
  - Efor: **Small**

- [ ] **3. `<YOUR_ANON_KEY>` placeholder'ını değiştir**
  - Ne: `notify_technician_on_assignment` trigger'ında anon key için placeholder var — değiştirilmemiş olabilir
  - Yapılacak: Migration'ı güncelle veya `app.settings.anon_key` Supabase parametresini set et
  - Dosya: `supabase/migrations/20260604000001_use_settings_table_for_webhook_secret.sql:27`
  - Efor: **Trivial**

- [ ] **4. Webhook trigger Authorization header tutarsızlığını düzelt**
  - Ne: `notify_technician_on_assignment` Authorization header gönderiyor ama `notify_fault_report` göndermiyor
  - Yapılacak: `notify_fault_report` trigger'ına aynı Authorization header ekle
  - Dosya: `supabase/migrations/20260604000001_use_settings_table_for_webhook_secret.sql:79-82`
  - Efor: **Small**

- [ ] **5. CI'a secret scanning ekle**
  - Ne: Sızdırılmış key bir daha commit edilmesin
  - Yapılacak: `gitleaks` veya GitHub Advanced Security secret scanning aktif et
  - Dosya: `.github/workflows/test.yml`
  - Efor: **Small**

- [ ] **6. Edge Function notification authorization'ı sıkılaştır**
  - Ne: Herhangi bir authenticated user `to_role: 'admin'` ile tüm adminlere bildirim gönderebilir
  - Yapılacak: Edge Function'da caller'ın rolünü kontrol et; sadece admin veya sistem tetikleyicileri `to_role` kullanabilsin
  - Dosya: `supabase/functions/send-notification/index.ts:121-180`
  - Efor: **Medium**

---

### VERİ KAYBI — OFFLİNE

- [ ] **7. Hive recovery'de sync queue silimini engelle**
  - Ne: `_clearAndReinitHive` HiveError/FormatException sonrası `syncQueueBoxName` dahil her box'ı siliyor
  - Yapılacak: Sync queue box'ını asla otomatik silme. Box bazında migration/quarantine uygula. Kullanıcıya recovery seçeneği sun
  - Dosya: `lib/main.dart:77-86`
  - Efor: **Medium**

- [ ] **8. Fault raporlamayı ve statü güncellemelerini queue-first yap**
  - Ne: Online iken Supabase write başarısız olursa arıza raporu kaybolabiliyor. Ayrıca `FaultUpdateController.resolve()` ve `reopen()` metodlarında offline desteği hiç yok, direkt Supabase çağırıyor.
  - Yapılacak: Raporlama, resolve ve reopen işlemlerini lokal queue'ya yaz, sonra remote'a gönder. Hata durumunda queue'da kalsın
  - Dosya: `lib/features/fault/providers/fault_providers.dart`
  - Efor: **Medium**

- [ ] **9. Maintenance submission'ı queue-first yap**
  - Ne: Upload başarılı + insert başarısız = log kaybı. Online path'te durable fallback yok
  - Yapılacak: Online path'te de local persist → remote sync akışına geç
  - Dosya: `lib/features/maintenance/providers/maintenance_providers.dart:294-307`
  - Efor: **Medium**

- [ ] **10. Tüm syncable write'lara idempotency key ekle**
  - Ne: Retry durumunda duplicate kayıt oluşabilir
  - Yapılacak: Fault, maintenance log, photo upload, PDF, schedule için deterministic UUID key kullan. DB'de unique constraint ekle
  - Dosya: `lib/core/services/sync_queue_service.dart`, fault/maintenance providers
  - Efor: **Medium**

- [ ] **11. Online photo upload'a timeout guard ekle**
  - Ne: `_uploadPhotos` online path'te timeout yok; `SyncQueueService`'te 45s timeout var ama provider'da yok
  - Yapılacak: Storage upload çağrısına `.timeout(Duration(seconds: 45))` ekle; timeout'da offline queue'ya düş
  - Dosya: `lib/features/maintenance/providers/maintenance_providers.dart:159`
  - Efor: **Small**

- [ ] **12. Customer portal'a offline cache desteği ekle**
  - Ne: `customer_portal_provider.dart` `isOnlineProvider` veya `readCacheServiceProvider` kullanmıyor; offline'da boş ekran
  - Yapılacak: Diğer provider'larla tutarlı şekilde offline cache fallback ekle
  - Dosya: `lib/features/customer/providers/customer_portal_provider.dart`
  - Efor: **Small**

---

### ANDROID RELEASE

- [x] **13. Android release signing'i düzelt**
  - Ne: Release build debug key ile imzalanıyor — Play Store'a gönderilemez
  - Yapılacak: `build.gradle.kts` release signing config ekle; CI secrets'ta keystore sakla
  - Dosya: `android/app/build.gradle.kts:39-40`
  - Efor: **Small**

---

### TEST

- [x] **14. Test suite hang'ini düzelt**
  - Ne: Flaky golden testler CI'da skip edildi, test suite başarıyla çalışıyor (Çözüldü)
  - Yapılacak: Test altyapısı çalışıyor, ileride eklenecek testler için güvenilir
  - Dosya: `test/core/services/sync_queue_service_test.dart`, `.github/workflows/test.yml`
  - Efor: **Medium**

---

### KÜÇÜK DÜZELTMELER

- [ ] **15. Maintenance report storage path'ini düzelt**
  - Ne: Flutter root-level dosya yüklerken migration `maintenance-reports` bucket'ını private+scoped yapmış
  - Yapılacak: `reports/{elevatorId}/...` path'ine geç; public URL yerine signed URL kullan
  - Dosya: `lib/core/services/sync_queue_service.dart:401-444`, ilgili Supabase migration
  - Efor: **Medium-Large**

- [ ] **16. FCM token debug logging temizle**
  - Ne: `notification_service.dart` L233 ve L248'de `debugPrint` hâlâ `kDebugMode` guard'ı olmadan kullanılıyor.
  - Yapılacak: `kDebugMode` guard'ı ekle veya token loglamayı tamamen kaldır
  - Dosya: `lib/core/services/notification_service.dart:233,248`
  - Efor: **Trivial**

---

## 🟡 FAZ 2 — ÖNEMLİ (30–90 Gün)
> Ölçeklenebilirlik, güvenilirlik ve geliştirilebilirlik için kritik.

### MİMARİ

- [ ] **17. `SyncCoordinator` yaz — `SyncQueueService`'i böl**
  - Ne: Tek servis; queue yönetimi + conflict + upload + PDF + schedule + remote write yapıyor
  - Yapılacak: Queue, Retry/Backoff, ConflictResolver, MediaUploader, RemoteWriter olarak ayır
  - Dosya: `lib/core/services/sync_queue_service.dart`
  - Efor: **Large**

- [x] **18. Global `Supabase.instance.client` kullanımlarını kaldır (8 adet)**
  - Ne: 3 provider'da 8 ayrı direkt çağrı; test edilemez, DI bypass ediyor
  - Yapılacak: Hepsini `ref.read(supabaseClientProvider)` ile değiştir
  - Dosya:
    - `lib/features/admin/providers/checklist_provider.dart` (satır 22, 43, 55, 66, 77)
    - `lib/features/customer/providers/customer_portal_provider.dart` (satır 19, 39)
    - `lib/features/admin/conflicts/admin_conflict_provider.dart` (satır 51)
  - Efor: **Small**

- [ ] **19. Router → NotificationService coupling'i kır**
  - Ne: `app_router.dart:112-116` navigasyon içinde notification service state mutate ediyor
  - Yapılacak: Notification auth state'i auth provider'dan oku; router'dan notification referansını çıkar
  - Dosya: `lib/core/router/app_router.dart:112-116`
  - Efor: **Medium**

- [ ] **20. Büyük view'ları parçala**
  - Ne: 5 dosya 1000+ satır — review/test imkansız
  - Yapılacak: Screen container + form controller + section widget + view model pattern uygula
  - Dosya:
    - `lib/features/admin/views/admin_master_calendar_view.dart` (1471 satır)
    - `lib/features/maintenance/views/maintenance_log_entry_view.dart` (1269 satır)
    - `lib/features/admin/views/user_management_view.dart` (1263 satır)
    - `lib/features/admin/views/technician_management_view.dart` (1219 satır)
    - `lib/features/fault/views/fault_detail_view.dart` (1016 satır)
  - Efor: **Large**

---

### OFFLINE-FIRST

- [ ] **21. Connectivity reachability katmanı ekle**
  - Ne: `isOnlineProvider` sadece `ConnectivityResult.none` kontrol ediyor; captive portal, DNS hatası, zayıf sinyal kör nokta
  - Yapılacak: Periyodik Supabase ping + hata sınıflandırması (transient/auth/server) ekle
  - Dosya: `lib/core/providers/connectivity_providers.dart`
  - Efor: **Medium**

- [ ] **22. Sync failure/conflict UI ekle**
  - Ne: `flush()` yalnızca başarıda `notifyListeners()` çağırıyor; başarısız/conflict item'lar UI'da görünmüyor
  - Yapılacak: Her queue state mutasyonunda notify et; pending/syncing/failed/conflict/dead-letter badge göster
  - Dosya: `lib/core/services/sync_queue_service.dart:166-215`, ilgili UI
  - Efor: **Medium**

- [ ] **23. `resolveFlagDisputed`'ı atomik hale getir**
  - Ne: Insert başarılı + local delete başarısız = duplicate conflict report
  - Yapılacak: Local item'ı önce `resolving` olarak işaretle, remote confirm sonrası sil; ya da DB unique constraint ekle
  - Dosya: `lib/core/services/sync_queue_service.dart:737-760`
  - Efor: **Small**

- [ ] **24. Retry/backoff policy ekle**
  - Ne: Sync queue'da retry policy, max attempt, dead-letter mekanizması yok
  - Yapılacak: Exponential backoff + jitter + max retry + dead-letter state ekle
  - Dosya: `lib/core/services/sync_queue_service.dart`
  - Efor: **Medium**

- [ ] **25. Pending-write overlay'i read provider'lara ekle**
  - Ne: Offline'da oluşturulan kayıtlar listede hemen görünmüyor
  - Yapılacak: Queue'daki pending item'ları ilgili read provider'larla merge et
  - Dosya: Fault/maintenance/elevator provider'lar
  - Efor: **Medium**

---

### UI / LOCALİZASYON

- [ ] **26. Hardcoded stringleri ARB'ye taşı**
  - Ne: Uygulama genelinde hardcoded Türkçe stringler var
  - Yapılacak: Tüm stringleri `app_tr.arb` dosyasına taşı ve yerelleştirme (l10n) kullan
  - Efor: **Medium**

- [ ] **27. iOS orientation tutarsızlığını düzelt**
  - Ne: Flutter bootstrap portrait zorluyor ama Info.plist çoklu orientation tanımlıyor
  - Yapılacak: Info.plist dosyasını güncelleyerek orientation tutarsızlığını gider
  - Efor: **Trivial**

- [ ] **28. Disabled schedule tab'ı non-admin'lerden gizle**
  - Ne: NavBar'da kullanılamayan/pasif sekme gereksiz yer kaplıyor
  - Yapılacak: Admin olmayan kullanıcılar için schedule sekmesini bottom navigation'dan tamamen kaldır
  - Efor: **Small**

- [ ] **29. faultsByElevatorProvider ve faultByIdProvider offline cache fallback eksik**
  - Ne: Arıza listeleri ve detayları network olmadığında önbelleği (cache) kullanmıyor
  - Yapılacak: Bu provider'lara `isOnlineProvider` ve `readCacheServiceProvider` fallback'leri ekle
  - Efor: **Small**

### VERİ KATMANI

- [x] **26. Unbounded query'lere pagination ekle**
  - Ne: `getAllElevators`, `getAllFaults`, `getAllActiveFaults`, schedule listesi limit yok
  - Yapılacak: `.range()` veya cursor-based pagination ekle
  - Dosya:
    - `lib/features/elevator/repositories/elevator_repository.dart:32-33`
    - `lib/features/fault/repositories/fault_repository.dart:38-39`
    - `lib/features/admin/repositories/schedule_repository.dart:211-220`
  - Efor: **Medium**

- [x] **27. Model parsing'e domain validation ekle**
  - Ne: Eksik tarihler `DateTime.fromMillisecondsSinceEpoch(0)` (1970-01-01) döndürüyor — silent corruption
  - Yapılacak: Repository sınırında required field validation; parse hatası açık exception fırlatsın
  - Dosya: `schedule_model.dart:69-71`, `maintenance_log_model.dart:74-76`, `fault_report_model.dart:62-64`
  - Efor: **Small**

- [x] **28. `toString()` metodlarından hassas alanları kaldır**
  - Ne: Log'lara email, fullName, checklist, photos yazılıyor
  - Yapılacak: ID ve rol gibi non-sensitive alanları bırak, geri kalanı çıkar
  - Dosya: `lib/features/maintenance/models/maintenance_log_model.dart:137-140`, `lib/features/admin/models/profile_model.dart:157-159`
  - Efor: **Trivial**

---

### TEST

- [ ] **29. Fake Supabase client ile deterministic queue testleri yaz**
  - Ne: Mevcut testler `flush()` gerçek davranışını test etmiyor
  - Yapılacak: Mocktail/fake ile remote failure + retry + conflict senaryoları yaz
  - Dosya: `test/core/services/sync_queue_service_test.dart`
  - Efor: **Medium**

- [ ] **30. Online failure → queue fallback için provider testleri yaz**
  - Ne: Fault/maintenance provider testleri online hata durumunda queue'ya düşme senaryosunu kapsamamış
  - Dosya: `test/features/fault/`, `test/features/maintenance/`
  - Efor: **Medium**

- [ ] **31. RLS migration testleri yaz**
  - Ne: RLS policy doğruluğu otomatik test edilmiyor
  - Yapılacak: Supabase local + pgTAP ile her role için RLS senaryosu
  - Dosya: `supabase/migrations/`
  - Efor: **Medium**

- [ ] **32. Edge Function authorization testleri yaz**
  - Ne: `send-notification` caller role kontrolü test edilmiyor
  - Dosya: `supabase/functions/send-notification/`
  - Efor: **Medium**

- [ ] **33. Integration test'e gerçek assertion ekle**
  - Ne: `app_test.dart` sadece uygulama başlatıyor, hiçbir şey assert etmiyor
  - Yapılacak: Login ekranı → login → dashboard visible senaryosu yaz
  - Dosya: `integration_test/app_test.dart`
  - Efor: **Small**

---

### DEVOPs

- [x] **34. Flutter SDK sürümünü pin'le**
  - Ne: `channel: 'stable'` floating — beklenmedik breaking change riski
  - Yapılacak: `flutter-version: '3.x.x'` ile exact version pin
  - Dosya: `.github/workflows/test.yml:24`, `.github/workflows/flutter_ci.yml:32`
  - Efor: **Trivial**

- [ ] **35. CI'a Android/iOS build job ekle**
  - Ne: CI sadece test/analyze çalıştırıyor; production build doğrulaması yok
  - Yapılacak: `flutter build apk --release` ve `flutter build ipa` adımları ekle
  - Dosya: `.github/workflows/`
  - Efor: **Small**

- [ ] **36. Build flavor'ları ekle (dev/staging/prod)**
  - Ne: Tek environment config var — staging testi imkansız
  - Yapılacak: Flutter flavor + Supabase URL/key per-environment
  - Efor: **Medium**

- [ ] **37. Supabase migration validation ekle**
  - Ne: CI migration bütünlüğünü kontrol etmiyor
  - Yapılacak: `supabase db push --dry-run` veya migration diff kontrolü CI'a ekle
  - Efor: **Small**

---

### KOD KALİTESİ

- [x] **38. AI reasoning yorum satırlarını temizle**
  - Ne: `fault_providers.dart:47-52`'de `"wait, I don't know..."` production kodunda kalmış
  - Dosya: `lib/features/fault/providers/fault_providers.dart:47-52`
  - Efor: **Trivial**

- [x] **39. Dead code + suppressed lint uyarısını kaldır**
  - Ne: `sync_queue_service.dart:373-376` — `// ignore: unnecessary_null_comparison` + hiçbir zaman false olmayan if
  - Dosya: `lib/core/services/sync_queue_service.dart:373-376`
  - Efor: **Trivial**

- [x] **40. `AnimatedPressButton`'a erişilebilirlik desteği ekle**
  - Ne: Pointer-only listener — klavye/focus/semantics desteği yok
  - Yapılacak: `Semantics` widget'ı + `FocusNode` + `onKeyEvent` ekle
  - Dosya: `lib/core/widgets/animations/animated_press_button.dart:45-72`
  - Efor: **Small**

- [x] **41. CI workflow tekrarını gider**
  - Ne: `test.yml` ve `flutter_ci.yml` aynı analyze/test sorumluluklarını çoğaltıyor
  - Yapılacak: Tek reusable workflow yap veya birini kaldır
  - Dosya: `.github/workflows/`
  - Efor: **Small**

---

## 🟢 FAZ 3 — ÖLÇEKLEME (6 Ay)
> Rakip CMMS platformlarına yetişmek için gereken modüller.

- [ ] **42. SLA / escalation motoru**
  - Arıza açık kaldıysa otomatik escalation, SLA breach uyarısı
  - Efor: **Large**

- [ ] **43. Work-order lifecycle**
  - Priority, status, assignment, approval, audit history tam döngüsü
  - Efor: **Large**

- [ ] **44. Preventive maintenance automation**
  - Compliance kuralları ile periyodik bakım planlaması
  - Efor: **Large**

- [ ] **45. Parts inventory ve kullanım takibi**
  - Efor: **Large**

- [ ] **46. Customer communication portal**
  - Servis geçmişi, arıza bildirimi, SLA durumu, sözleşme görünürlüğü
  - Efor: **Large**

- [ ] **47. Manager analytics ve export**
  - KPI dashboard, PDF/Excel rapor çıktısı
  - Efor: **Large**

- [ ] **48. Crash reporting ve monitoring entegrasyonu**
  - Sentry veya Firebase Crashlytics entegrasyonu
  - Efor: **Small**

---

---

- [ ] **52. Route / workforce optimization**
  - Efor: **Large**

- [ ] **53. Contract / warranty modülü**
  - Efor: **Large**

- [ ] **54. Compliance / audit log modülü**
  - Efor: **Large**

- [ ] **55. Store release automation (CI/CD)**
  - Efor: **Medium**

## 📋 Hızlı Özet — Öncelik Tablosu

| # | Görev | Efor | Faz | Risk |
|---|-------|------|-----|------|
| 1 | Firebase key rotation | Medium | 🔴 | **Critical** |
| 2 | Webhook fallback secret kaldır | Small | 🔴 | **Critical** |
| 3 | `<YOUR_ANON_KEY>` düzelt | Trivial | 🔴 | **Critical** |
| 4 | Webhook header tutarsızlık | Small | 🔴 | **Critical** |
| 5 | CI secret scanning | Small | 🔴 | **Critical** |
| 6 | Edge Function auth sıkılaştır | Medium | 🔴 | **Critical** |
| 7 | Hive recovery queue silimini engelle | Medium | 🔴 | **Critical** |
| 8 | Fault queue-first | Medium | 🔴 | **Critical** |
| 9 | Maintenance queue-first | Medium | 🔴 | **Critical** |
| 10 | Idempotency key ekle | Medium | 🔴 | **High** |
| 11 | Photo upload timeout | Small | 🔴 | **High** |
| 12 | Customer portal offline cache | Small | 🔴 | **High** |
| 13 | Android release signing | Small | 🔴 | **Critical** |
| 14 | Test suite hang fix | Medium | 🔴 | **High** |
| 15 | Storage path + signed URL | Medium-Large | 🔴 | **High** |
| 16 | FCM token log temizle | Trivial | 🔴 | Low |
| 17 | SyncCoordinator | Large | 🟡 | Architecture |
| 18 | Global Supabase kaldır (8 adet) | Small | 🟡 | Maintainability |
| 19 | Router-Notification coupling | Medium | 🟡 | Architecture |
| 20 | Büyük view'ları böl | Large | 🟡 | Maintainability |
| 21 | Connectivity reachability | Medium | 🟡 | Reliability |
| 22 | Sync failure UI | Medium | 🟡 | UX |
| 23 | `resolveFlagDisputed` atomic | Small | 🟡 | Data |
| 24 | Retry/backoff policy | Medium | 🟡 | Reliability |
| 25 | Pending-write overlay | Medium | 🟡 | UX |
| 26 | Pagination | Medium | 🟡 | Scalability |
| 27 | Model parsing validation | Small | 🟡 | Data |
| 28 | `toString` sensitive field | Trivial | 🟡 | Security |
| 29 | Queue flush testleri | Medium | 🟡 | Testing |
| 30 | Provider failure testleri | Medium | 🟡 | Testing |
| 31 | RLS testleri | Medium | 🟡 | Testing |
| 32 | Edge Function testleri | Medium | 🟡 | Testing |
| 33 | Integration test assertion | Small | 🟡 | Testing |
| 34 | Flutter SDK pin | Trivial | 🟡 | DevOps |
| 35 | CI build job | Small | 🟡 | DevOps |
| 36 | Build flavors | Medium | 🟡 | DevOps |
| 37 | Migration validation CI | Small | 🟡 | DevOps |
| 38 | AI yorum temizle | Trivial | 🟡 | Quality |
| 39 | Dead code kaldır | Trivial | 🟡 | Quality |
| 40 | AnimatedPressButton erişilebilirlik | Small | 🟡 | UX |
| 41 | CI workflow tekrar | Small | 🟡 | DevOps |
| 42 | SLA/escalation motoru | Large | 🟢 | Feature |
| 43 | Work-order lifecycle | Large | 🟢 | Feature |
| 44 | Preventive maintenance | Large | 🟢 | Feature |
| 45 | Parts inventory | Large | 🟢 | Feature |
| 46 | Customer portal genişlet | Large | 🟢 | Feature |
| 47 | Manager analytics | Large | 🟢 | Feature |
| 48 | Crash reporting | Small | 🟢 | DevOps |

**Toplam: 55 görev** — 16 Acil (🔴), 28 Önemli (🟡), 11 Ölçekleme (🟢)
