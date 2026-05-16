# 🚀 ASANSÖR PROJESİ - MASTER KNOWLEDGE BASE

Bu doküman, Asansör Bakım & Arıza Takip Sistemi projesinin **Tek Kaynak Gerçeği (Single Source of Truth)** olarak tasarlanmıştır. Bu dokümanı okuyan bir geliştirici veya AI ajanı, projenin mimarisine, çalışma prensiplerine ve kurallarına tam hakimiyet sağlayabilir.

---

## 1. 🎯 Proje Vizyonu ve Amacı
Asansör Bakım & Arıza Takip Sistemi, asansör servis firmalarının saha operasyonlarını dijitalleştiren, çevrimdışı çalışma desteği sunan ve gerçek zamanlı bildirimlerle yönetimi kolaylaştıran bir ekosistemdir.

### Ana Kullanıcı Grupları:
- **Saha Teknisyenleri:** QR kod tarayarak asansör bilgilerine erişir, bakım formlarını (offline destekli) doldurur, arıza raporlar.
- **Yöneticiler (Admin):** Görev ataması yapar, harita üzerinden ekipleri izler, raporları onaylar ve KPI takibi yapar.

---


## 3. 🛠 Teknoloji Yığını

### Frontend (Flutter)
- **State Management:** `flutter_riverpod` (Notifier/AsyncNotifier pattern).
- **Routing:** `go_router` (Role-based guarding).
- **Local Persistence:** `hive` (Cache & Sync Queue).
- **UI:** Material 3, Dark Theme.
- **PDF & Raporlama:** `pdf`, `printing`.

### Backend (Supabase)
- **Database:** PostgreSQL (RLS enabled).
- **Auth:** Supabase Auth (Email/Password).
- **Storage:** Supabase Storage (Buckets: `fault-images`, `maintenance-records`, `maintenance-reports`).
- **Logic:** Edge Functions (Deno + TypeScript).

### Bildirim Sistemi
- **FCM v1:** Firebase Cloud Messaging.
- **Trigger:** DB Trigger -> Edge Function -> FCM.

---

## 4. 🏗 Mimari Yapı (Feature-First)

Proje `lib/features/` altında modüler bir yapıda organize edilmiştir. Her modül şu alt klasörlere sahiptir:

```text
feature_name/
├── data/           # Opsiyonel: Raw data sources
├── models/         # JSON Serializable modeller
├── repositories/   # Supabase/API çağrıları
├── providers/      # Riverpod Notifier'ları ve State
└── presentation/   # UI (Views, Widgets)
```

### Kritik Servisler (`lib/core/services/`)
- **`SyncQueueService`:** Çevrimdışı yapılan işlemleri sıraya alır ve internet geldiğinde otomatik senkronize eder.
- **`PdfService`:** Kurumsal bakım ve muayene raporları üretir.
- **`NotificationService`:** Push ve yerel bildirimleri yönetir.
- **`ReadCacheService`:** Verilerin çevrimdışı okunabilmesi için lokal önbellekleme yapar.

---

## 5. 🗄 Veritabanı Şeması ve Veri Akışı

### Ana Tablolar
1. **`elevators`:** Asansörlerin statik bilgileri ve konumu.
2. **`profiles`:** Kullanıcı rolleri ve FCM tokenları.
3. **`maintenance_logs`:** Gerçekleşen bakım kayıtları (Fotoğraflar ve imzalar JSONB/URL olarak).
4. **`fault_reports`:** Arıza bildirimleri ve çözüm notları.
5. **`maintenance_schedules`:** Planlanmış görevler.

### Çevrimdışı Yazma Akışı (Offline Sync)
1. Kullanıcı işlemi yapar (örn. Bakım Tamamla).
2. Veri `Hive` kutusuna (`syncQueueBox`) kaydedilir.
3. `SyncQueueService` internet bağlantısını dinler.
4. Bağlantı geldiğinde:
   - Dosyalar (resim/imza) Storage'a yüklenir.
   - URL'ler payloada eklenir.
   - Supabase DB'ye `insert/update` yapılır.
   - Kuyruktan silinir.

---

## 🚦 Geliştirme Standartları ve Kurallar

### 1. Yeni Bir Özellik Ekleme Adımları
Herhangi bir ajan veya geliştirici yeni bir özellik eklerken şu sırayı izlemelidir:

1.  **Veri Modeli:** `lib/features/<feature>/models/` altında model oluşturulur (JSON serialization ile).
2.  **Veritabanı:** Eğer gerekliyse, **supabase-dev** ajanı `supabase/migrations/` altında SQL dosyasını hazırlar.
3.  **Repository:** `lib/features/<feature>/repositories/` altında Supabase CRUD işlemleri yazılır.
4.  **Provider:** `lib/features/<feature>/providers/` altında `Notifier` veya `AsyncNotifier` ile state yönetimi kurulur.
5.  **UI (Presentation):** `lib/features/<feature>/presentation/` altında ekranlar ve widgetlar oluşturulur.
6.  **Offline Support:** Eğer veri yazılıyorsa, `SyncQueueService` entegrasyonu yapılır.

### 2. Riverpod Kullanım Kuralları
- Global state için her zaman `Notifier` veya `AsyncNotifier` tercih edin.
- `ref.watch` UI içinde, `ref.read` ise buton tıklamaları gibi aksiyonlarda kullanılmalıdır.
- Karmaşık logic'leri Provider içinde tutun, View'ları olabildiğince "dumb" bırakın.

### 3. Çevrimdışı Senkronizasyon (Hive)
- Her yeni model için bir Hive `Adapter` oluşturulmalı ve `main.dart` içinde kaydedilmelidir.
- Önemli veriler (asansörler, görevler) için her zaman bir `cacheBox` kullanılmalıdır.

---

---

## 📅 Roadmap & Gelecek Planları
- [ ] **Fotoğraf Yükleme Geliştirmesi:** Arıza raporlarına çoklu fotoğraf desteği.
- [ ] **Gerçek Zamanlı Takip:** Teknisyenlerin canlı lokasyonunun haritaya eklenmesi.
- [ ] **Müşteri Paneli:** Bina yöneticileri için sınırlı yetkili izleme ekranı.
- [ ] **Gelişmiş İstatistikler:** Admin dashboard için grafiksel raporlar.

---

> [!TIP]
> Bu doküman her büyük mimari değişiklikte güncellenmelidir. Projenin hafızası bu dosyadır.
