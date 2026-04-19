# Asansor — Asansör Bakım & Arıza Takip Sistemi

Teknisyenlere ve yöneticilere yönelik, Supabase tabanlı bir mobil bakım yönetimi uygulaması.

---

## Proje Amacı

İki farklı kullanıcı grubuna hizmet eden bir mobil uygulama:

- **Teknisyenler** — sahada asansör bakımı yapan ekip; QR okuyarak asansöre ulaşır, arıza bildirir, bakım kaydeder.
- **Yöneticiler / Adminler** — bakım süreçlerini planlayan ve izleyen ofis tarafı; teknisyenlere görev atar, istatistikleri takip eder, canlı haritayı izler.

---

## Teknoloji Yığını

| Katman | Teknoloji |
|---|---|
| Frontend | Flutter (Dart) |
| Backend & Veritabanı | Supabase (PostgreSQL + Auth) |
| State Management | flutter_riverpod |
| Routing | go_router |
| Harita | flutter_map + OpenStreetMap (API key gerektirmez) |
| QR Tarama | mobile_scanner |
| Ortam Değişkenleri | flutter_dotenv |

---

## Mimari

**Feature-first** klasör yapısı. Her özellik kendi içinde bağımsız:

```
lib/
├── core/
│   ├── constants/   → Supabase URL/Key (dotenv üzerinden)
│   └── router/      → GoRouter (tüm rotalar + auth redirect)
└── features/
    ├── auth/        → Giriş ekranı, Supabase Auth
    ├── elevator/    → QR tarama, asansör detayı, teknisyen dashboard
    ├── fault/       → Arıza raporlama
    ├── maintenance/ → Bakım logları
    └── admin/       → Admin paneli, görev atama, canlı harita
```

Her feature içindeki katmanlar:

```
<feature>/
├── models/          → Supabase tablo modelleri (fromJson / toJson)
├── repositories/    → Supabase CRUD çağrıları
├── providers/       → Riverpod Provider'ları (state yönetimi)
└── views/           → Flutter UI ekranları
```

---

## Veritabanı Şeması (Supabase)

| Tablo | Açıklama |
|---|---|
| `elevators` | Bina adı, adres, durum, harita koordinatları |
| `fault_reports` | Arıza raporları (asansör ID, açıklama, çözüldü mü?) |
| `maintenance_logs` | Teknisyenin girdiği bakım notları ve onay durumu |
| `maintenance_schedules` | Yöneticinin atadığı planlı görevler (teknisyen, tarih, durum) |

Harita özelliği için gerekli sütunlar:

```sql
alter table elevators add column latitude  double precision;
alter table elevators add column longitude double precision;
```

---

## Uygulama Rotaları

| Rota | Ekran |
|---|---|
| `/login` | Giriş ekranı |
| `/` | Teknisyen dashboard (HomeView) |
| `/scan` | QR kod tarayıcı |
| `/elevator/:id` | Asansör detay ekranı |
| `/admin/dashboard` | Admin kontrol paneli |
| `/admin/assign` | Teknisyene görev atama formu |
| `/admin/map` | Canlı operasyon haritası |

---

## Tamamlanan Özellikler

### Teknisyen Akışı
- E-posta/şifre ile giriş; oturum durumuna göre otomatik yönlendirme
- Dashboard: aktif arızalar (yatay kart), atanmış görevler, istatistik bento grid
- QR tarayıcı → asansör detay sayfasına yönlendirme
- Asansör detayı: durum rozeti, bakım geçmişi zaman çizelgesi
- "Arıza Bildir" ve "Bakım Ekle" bottom sheet formları (Supabase'e kaydeder)

### Admin Akışı
- 4 KPI kartı: toplam asansör, açık arıza, ay içi tamamlanan/bekleyen
- Tüm görevlerin listesi (durum rozeti, tarih, teknisyen bilgisi)
- Teknisyene görev atama formu (asansör seçici, UUID girişi, tarih/saat seçici)
- Canlı operasyon haritası (flutter_map + OpenStreetMap):
  - 🔴 Kırmızı → çözülmemiş aktif arıza
  - 🟡 Sarı → bugün planlı bakım var
  - 🟢 Yeşil → sorunsuz, normal durum
  - Marker'a tıklayınca bina bilgisi + "Detayları Gör" bottom sheet'i

---

## Kurulum

### 1. Ortam Değişkenleri

Proje kök dizininde `.env` dosyası oluştur:

```
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

> `.env` dosyası `.gitignore`'a eklidir; asla commit'leme.  
> Format için `.env.example` dosyasına bak.

### 2. Bağımlılıkları Yükle

```bash
flutter pub get
```

### 3. Çalıştır

```bash
flutter run
```

---

### Çok Rollu Kullanıcı Sistemi
- `profiles` tablosu: `id`, `email`, `full_name`, `phone`, `role` (`admin` | `technician` | `customer`), `elevator_id`
- Giriş sonrası profil otomatik yüklenir; `roleProvider` UI'de, `routerRoleNotifier` router'da rol kontrolü sağlar
- Admin rotaları (`/admin/*`) rol guard ile korunur — non-admin kullanıcılar `/` adresine yönlendirilir
- **Kullanıcı Yönetimi ekranı** (`/admin/users`): Teknisyenler / Müşteriler / Tüm Kullanıcılar sekmeleri
  - Her kullanıcı kartı: avatar, isim, e-posta, telefon, rol rozeti
  - "Rol Değiştir" bottom sheet (admin only)
  - Müşteri sekmesi: hangi asansöre bağlı olduğunu gösterir + "Asansör Ata / Değiştir" aksiyonu
- Admin Dashboard'a "Kullanıcı Yönetimi" kartı eklendi

SQL kurulumu için `lib/features/admin/models/profile_model.dart` dosyasındaki belgeye bak.

### Şeffaflık Raporu (PDF)
- Asansör detay ekranındaki 📄 PDF ikonuna tıklayarak son 6 aylık bakım geçmişinin kurumsal PDF raporu oluşturulur
- Rapor içeriği: başlık, asansör bilgileri, bakım tablosu (Tarih / Teknisyen / Notlar / Onay), imza ve zaman damgası
- Türkçe karakter desteği: Nunito Sans (Google Fonts); indigo/lacivert kurumsal tasarım
- Yazdırma / kaydetme önizlemesi `Printing.layoutPdf` ile sağlanır

---

## Eksik / Yapılmayı Bekleyenler

- **Rol tabanlı erişim** — Admin rotaları şu an herkese açık. `profiles` tablosuna `role` sütunu eklendiğinde GoRouter'a guard eklenecek.
- **Fotoğraf yükleme** — `image_picker` paketi hazır; arıza raporuna fotoğraf ekleme henüz entegre değil.
- **Gerçek koordinatlar** — Haritada görünebilmesi için `elevators` tablosuna `latitude`/`longitude` doldurulmalı.
- **Push Bildirimleri** — Supabase Realtime veya Firebase Cloud Messaging ile.
- **Teknisyen profil sayfası** — Profil düzenleme ve `profiles` tablosu entegrasyonu.
- **Profil tablosuna dayalı teknisyen seçici** — Şu an UUID manuel giriliyor; `profiles` tablosu oluşturulduğunda dropdown ile değiştirilecek.
