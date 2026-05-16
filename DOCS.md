# Asansör Projesi: Teknik Mimari ve Sistem Dokümantasyonu

Bu belge, Asansör uygulamasının teknik yapısını, veri akışını ve kritik sistem mekanizmalarını başka bir geliştirici veya yapay zeka ajanı tarafından tam olarak anlaşılabilmesi için özetler.

## 1. Genel Bakış
Uygulama, asansör bakım, arıza takibi ve teknik ekip yönetimini sağlayan "Industrial Dark" temalı bir mobil platformdur. Offline-first (önce çevrimdışı) çalışma prensibiyle tasarlanmıştır.

## 2. Teknoloji Yığını
- **Frontend:** Flutter (Dart)
- **State Management:** Riverpod (AsyncNotifier & Provider)
- **Routing:** GoRouter (Role-based guarding & Deep Linking)
- **Backend/Database:** Supabase (PostgreSQL, Auth, RLS)
- **Offline Storage:** Hive (NoSQL)
- **Notifications:** Firebase Cloud Messaging (FCM) v1 via Supabase Edge Functions
- **Real-time:** Supabase Realtime & Database Webhooks

## 3. Mimari Yapı (Feature-First)
Proje `lib/features/` dizini altında modüler bir yapıda organize edilmiştir:
- **Core:** Paylaşılan servisler (Sync, Notification, Router, Theme, Widgets).
- **Features:** 
    - `auth`: Giriş ve yetkilendirme.
    - `elevator`: Asansör listesi (Infinite Scroll), QR tarama, detaylar.
    - `maintenance`: Bakım planlama, tamamlama ve geçmiş.
    - `fault`: Arıza bildirimleri ve çözümü.
    - `notification`: Bildirim geçmişi (Infinite Scroll) ve push yönetimi.
    - `admin`: Panel, kullanıcı yönetimi, takvim ve harita.

## 4. Kritik Sistem Mekanizmaları

### A. Çevrimdışı Senkronizasyon (Sync Queue)
`SyncQueueService`, internet yokken yapılan işlemleri Hive (`sync_queue` box) üzerinde depolar.
- **İşleyiş:** Connectivity değiştiğinde bekleyen payload'lar Supabase'e sırayla gönderilir.
- **Tarih Eşleme:** Bakım işlemleri, `schedule_id` üzerinden veritabanındaki takvimle eşleşir.

### B. Güvenlik ve RLS (Row Level Security)
Tüm tablolar RLS ile korunmaktadır:
- **Profil:** Herkes kendi profilini görebilir.
- **Erişim:** `auth.uid()` ve `role` bazlı politikalar (SELECT, INSERT, UPDATE) tüm ana tablolarda (`elevators`, `fault_reports`, `maintenance_logs`, `maintenance_schedules`, `notifications`) aktiftir.

### C. Push Bildirimleri ve Derin Bağlantı (Deep Linking)
- **Navigasyon:** Bildirim tıklandığında `NotificationService` payload'u çözümler ve `GoRouter` ile kullanıcıyı doğrudan ilgili sayfaya yönlendirir.
- **Standard:** Edge Function'lar FCM HTTP v1 API kullanır.

### D. Hata Yönetimi (Error Handling)
- **ErrorBoundary:** Uygulama genelinde hataları yakalayan ve modern bir hata ekranı (`ErrorBoundaryScreen`) sunan merkezi yapı.

## 5. Veri Modeli ve Tablolar
- `profiles`: Kullanıcı rolleri ve FCM tokenları.
- `elevators`: Asansör teknik verileri (model, kapasite, konum).
- `fault_reports`: Arıza kayıtları ve çözüm durumları.
- `maintenance_logs`: Gerçekleşen bakım kayıtları.
- `maintenance_schedules`: Planlanan görev takvimi.
- `notifications`: Kullanıcı bazlı bildirim geçmişi.
- `checklist_items`: Bakım formları için dinamik kontrol listesi öğeleri.

## 6. UI/UX Tasarım Sistemi
"Industrial Dark" teması `AppColors` sınıfında tanımlanan token'lar üzerinden yönetilir:
- **Background:** `#0F172A` (Slate-900)
- **Surface:** `#1E293B` (Slate-800)
- **Typography:** `textPrimary`, `textSecondary`, `textMuted` semantik tokenları kullanılır.
- **Performance:** Büyük listelerde `ScrollController` tabanlı Infinite Scroll uygulanmıştır.

## 7. Geliştirme Kuralları (Agent Rules)
- **flutter-dev:** `lib/` dizini, Riverpod, GoRouter.
- **supabase-dev:** `supabase/` dizini, Migrations, Edge Functions.
- **qa-tester:** `test/` dizini, Unit/Integration tests.

## 8. Gelecek Planları (Roadmap)
- [x] FCM v1 tam geçişi (Legacy kodların temizlenmesi ve standardizasyon).
- [ ] Supabase Storage için RLS politikalarının sıkılaştırılması.
- [ ] Arıza fotoğrafları için çoklu yükleme desteği.
- [ ] Harita üzerinde teknisyen canlı konum takibi.

---
*Bu dosya sistemin yaşayan bir özetidir. Son güncelleme: 10 Mayıs 2026 (Antigravity).*
