# 🛗 Asansör Bakım ve Arıza Takip Sistemi (Asansor)

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![Riverpod](https://img.shields.io/badge/Riverpod-%2302569B.svg?style=for-the-badge&logo=flutter&logoColor=white)](https://riverpod.dev)
[![Hive](https://img.shields.io/badge/Hive-Local%20DB-orange?style=for-the-badge&logo=sqlite&logoColor=white)](https://pub.dev/packages/hive)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

Asansör Bakım ve Arıza Takip Sistemi, asansör firmaları, teknisyenler ve bina yöneticileri/müşteriler arasındaki iş akışını dijitalleştiren ve optimize eden mobil öncelikli bir **Flutter** uygulamasıdır. 

Uygulama, internet bağlantısının kesintili veya hiç olmadığı bodrum katları, asansör boşlukları gibi alanlarda kesintisiz çalışabilmek amacıyla **Offline-First (Önce Yerel Veri)** prensibiyle tasarlanmıştır.

---

## ✨ Öne Çıkan Özellikler

### 📶 Offline-First & Akıllı Senkronizasyon (Sync Queue)
- **Çevrimdışı Çalışma Kabiliyeti:** Teknisyenler, internet erişimi olmasa dahi bakım formlarını doldurabilir, arızaları güncelleyebilir ve yeni kayıtlar oluşturabilir.
- **İyimser Güncelleme (Optimistic Updates):** Yapılan işlemler yerel veritabanında (Hive) anında güncellenir ve kullanıcıya akıcı bir deneyim sunulur.
- **Sync Queue (Senkronizasyon Kuyruğu):** İnternet bağlantısı geldiği anda bekleyen tüm işlemler (Yaratma, Güncelleme, Silme vb.) sırasıyla ve güvenli bir şekilde Supabase bulut veritabanına aktarılır.
- **Çakışma Yönetimi (Optimistic Concurrency Control - OCC):** `version` takibi ile veri çakışmaları akıllıca yönetilir.

### 👥 Rol Tabanlı Yetkilendirme (Role-Based Access)
Uygulama üç farklı kullanıcı rolü için özelleştirilmiş arayüzler ve yetkiler sunar:
- **👑 Yönetici (Admin):** Müşteri ve teknisyen yönetimi, asansör tanımlama, periyodik bakım planlama ve genel istatistik takibi.
- **🔧 Teknisyen (Technician):** Kendisine atanan periyodik bakımları ve acil arıza bildirimlerini görüntüleme, bakım adımlarını kaydetme ve işi tamamlama.
- **🏢 Müşteri / Bina Yöneticisi (Customer):** Sorumlu olduğu binalardaki asansörlerin durumunu izleme, yeni arıza bildirimi oluşturma ve geçmiş bakım raporlarını inceleme.

### 🛡️ Güvenlik ve RLS (Row Level Security)
- Supabase PostgreSQL katmanında gelişmiş RLS politikaları tanımlanmıştır. 
- Her rol yalnızca görmeye yetkili olduğu tabloları ve satırları okuyup yazabilir.

---

## 🛠️ Teknoloji Yığını ve Kütüphaneler

- **Çatı (Framework):** SDK 3.x+ destekli Flutter
- **Durum Yönetimi (State Management):** [Flutter Riverpod](https://pub.dev/packages/flutter_riverpod) (Notifier, StateNotifier, AsyncNotifier)
- **Veritabanı ve Servisler (Backend):** [Supabase](https://supabase.com) (Auth, PostgreSQL, Realtime)
- **Yerel Önbellekleme (Local Storage):** [Hive](https://pub.dev/packages/hive) & [Hive Flutter](https://pub.dev/packages/hive_flutter)
- **Yönlendirme (Routing):** [go_router](https://pub.dev/packages/go_router)
- **Bağımlılık Enjeksiyonu & Servis Yönetimi:** Riverpod Providers
- **Test Araçları:** `flutter_test`, `mocktail` (Birim ve entegrasyon testleri için)

---

## 📂 Proje Yapısı (Mimari)

Temiz Mimari (Clean Architecture) ve Özellik Tabanlı (Feature-First) klasörleme yapısı benimsenmiştir:

```text
lib/
├── core/                         # Ortak ve temel altyapı servisleri
│   ├── network/                  # İnternet bağlantı denetleyicisi
│   ├── router/                   # go_router rota tanımları
│   ├── services/                 # SyncQueueService, ReadCacheService vb.
│   ├── theme/                    # Uygulama genel tema ve renk paleti
│   └── widgets/                  # Ortak UI bileşenleri (Navigasyon vb.)
│
├── features/                     # Uygulama özellikleri
│   ├── admin/                    # Yönetici paneli, teknisyen istatistikleri ve planlama
│   ├── auth/                     # Giriş, kayıt ve şifre işlemleri
│   ├── customer/                 # Müşteri ekranları ve arıza bildirim formu
│   ├── elevator/                 # Asansör tanımlama ve yönetim modelleri
│   ├── fault/                    # Arıza kayıtları, raporlar ve durum güncellemeleri
│   └── maintenance/              # Periyodik bakım formları, adımları ve geçmişi
│
└── main.dart                     # Uygulama başlangıç noktası (Initialization)
```

---

## 🚀 Kurulum ve Başlangıç

### Gereksinimler
- Bilgisayarınızda **Flutter SDK** (v3.19.0 veya üzeri) kurulu olmalıdır.
- Supabase hesabı ve aktif bir proje.

### Adım Adım Kurulum

1. **Projeyi Klonlayın:**
   ```bash
   git clone https://github.com/kullaniciadi/Asansor.git
   cd Asansor
   ```

2. **Bağımlılıkları Yükleyin:**
   ```bash
   flutter pub get
   ```

3. **Supabase Kurulumu:**
   Supabase panelinizde aşağıdaki tabloları ve RLS kurallarını oluşturun:
   - `profiles` (id, email, role, full_name)
   - `elevators` (id, name, building_name, address, status, created_at)
   - `fault_reports` (id, elevator_id, title, description, status, reported_by, assigned_technician_id, created_at, version)
   - `maintenances` (id, elevator_id, technician_id, status, checklist, notes, scheduled_at, completed_at, version)
   - `sync_queue` (yerel önbellekteki çevrimdışı kuyruk işlemleri için Hive üzerinde tutulur)

4. **Çevresel Değişkenleri Tanımlayın:**
   Supabase URL ve Anon Key bilgilerinizi uygulamanın ilgili konfigürasyon dosyasına veya `.env` yapısına entegre edin.

5. **Uygulamayı Çalıştırın:**
   ```bash
   flutter run
   ```

---

## 🧪 Testler ve Kalite Standartları

Projede iş mantığı (Business Logic), modeller, senkronizasyon mekanizmaları ve yerel servisler için kapsamlı unit testler yazılmıştır. Test kapsama oranı (coverage) oldukça yüksektir.

### Testleri Çalıştırma
Tüm birim testleri tek bir komutla çalıştırabilirsiniz:
```bash
flutter test
```

### Kod Formatlama
CI/CD süreçlerinde hata almamak için kodunuzu push etmeden önce aşağıdaki komutla formatlayın:
```bash
dart format .
```

---

## 🔒 Lisans

Bu proje [MIT Lisansı](LICENSE) altında lisanslanmıştır. Daha fazla bilgi için `LICENSE` dosyasına göz atabilirsiniz.
