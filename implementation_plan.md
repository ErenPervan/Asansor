# Sprint 1 (Phase 0): Kritik Hatalar ve Temel Düzeltmeler — Implementation Plan

**GitHub Issue:** [#3 Sprint 1 (Phase 0): Kritik Hatalar ve Temel Düzeltmeler](https://github.com/ErenPervan/Asansor/issues/3)  
**Hazırlanma Tarihi:** 2026-06-04  
**Statik Analiz Kaynağı:** Tüm dosyalar satır-satır tarandı, aşağıdaki veriler doğrulanmış bulgulardır.  
**Tahmini Efor:** 3–4 iş günü

---

## Bağlam & Kesin Durum Analizi

Statik kod taraması şu kritik bulguları ortaya koydu:

| Dosya | Satır Sonu | Mojibake Şiddeti | Etkilenen String Sayısı |
|---|---|---|---|
| `admin_statistics_dashboard.dart` | LF | **ÇOK AĞIR (çift/üçlü encoding)** | ~30+ |
| `fault_detail_view.dart` | **CRLF** | Orta | ~28 |
| `technician_management_view.dart` | LF | Orta | ~23 |
| `pdf_service.dart` | LF | Orta | ~22 |
| `log_maintenance_sheet.dart` | LF | Orta | ~12 |
| `elevator_maintenance_history.dart` | LF | Hafif | ~8 |
| `maintenance_log_entry_view.dart` | **CRLF** | **YOK — Temiz dosya** | 0 |

> [!IMPORTANT]
> **Kritik tespit:** `maintenance_log_entry_view.dart` dosyasındaki Türkçe string'ler (`'Bakımı Kaydet'`, `'Lütfen kaydetme işlemi...'` vb.) **doğru UTF-8 encoding ile yazılmış**. Bu dosyada yalnızca nested button yapısal hatası var, encoding sorunu yok.

> [!WARNING]
> **`admin_statistics_dashboard.dart`** dosyası çift/üçlü encoding kurbanı — UTF-8 byte'ları Latin-1 olarak okunmuş, o çıktı tekrar yanlış encode edilmiş. Bu dosyadaki mojibake diğerlerine kıyasla çok daha karmaşık ve comment satırları dahil her yerde mevcut.

> [!WARNING]
> **`test.yml` CI dosyasında kritik hatalar var** (plan kapsamına eklendi):
> - `.env` dummy dosyası oluşturulmuyor → build sırasında başarısız olur
> - `dart format --set-exit-if-changed .` komutu mojibake içeren dosyalarda **başarısız olur** (encoding hatalarını format hatası olarak algılar)
> - Her iki workflow da `Flutter CI` olarak adlandırılmış (isim çakışması)

---

## Kararlar (Onaylandı)

> [!NOTE]
> **Karar 1 — ARB Kapsam:** Sprint 1'de yalnızca `maintenance_log_entry_view.dart` + auth ekranı string'leri ARB'ye taşınacak. Diğer ekranlar Sprint 2–3'te kademeli geçecek. Gerekçe: Encoding fix PR'ını genişletmemek ve production'a çıkış hızını korumak.

> [!NOTE]
> **Karar 2 — Long-Press:** Fault detail ekranındaki long-press aksiyonu **tamamen kaldırılacak**, yerine görünür buton konacak. Gerekçe: Arızayı onar/yeniden aç, uygulamanın en kritik iş aksiyonu — primary action'lar her zaman tek dokunuşla erişilebilir olmalı. WCAG 2.5.1 bunu zorunlu kılıyor.

---

## Önerilen Değişiklikler

---

### Workstream 1 — Mojibake Encoding Düzeltmeleri

Uygulama sırası şiddete göre belirlendi (en kritik önce):

---

#### [MODIFY] [admin_statistics_dashboard.dart](file:///d:/Asansor/lib/features/admin/views/admin_statistics_dashboard.dart)

**Şiddet: ÇOK AĞIR — Çift/üçlü mojibake**

> [!CAUTION]
> Bu dosyada `// ──` gibi yorum satırı ayraçları da bozulmuş. Dosyayı doğrudan bir metin editöründe düzeltmeye çalışmak yerine VS Code ile `Reopen with Encoding → UTF-8` yaklaşımı denenmelidir. Eğer bu çalışmazsa, aşağıdaki string'ler manuel olarak tek tek düzeltilmelidir.

| Satır | Bozuk Metin | Doğru Türkçe |
|---|---|---|
| 82 | `'Aktif ArÃƒâ€Ã‚Â±zalar'` | `'Aktif Arızalar'` |
| 83 | `'ÃƒÆ'Ã¢â‚¬Â¡ÃƒÆ'Ã‚Â¶zÃƒÆ'Ã‚Â¼m bekliyor'` | `'Çözüm bekliyor'` |
| 87 | `'GÃƒÆ'Ã‚Â¼ncel'` | `'Güncel'` |
| 92 | `'Bu Ay ÃƒÆ'Ã¢â‚¬Â¡ÃƒÆ'Ã‚Â¶zÃƒÆ'Ã‚Â¼len'` | `'Bu Ay Çözülen'` |
| 93 | `'Tamamlanan gÃƒÆ'Ã‚Â¶revler'` | `'Tamamlanan görevler'` |
| 102 | `'Toplam AsansÃƒÆ'Ã‚Â¶r'` | `'Toplam Asansör'` |
| 103 | `'Sistemde kayÃƒâ€Ã‚Â±tlÃƒâ€Ã‚Â±'` | `'Sistemde kayıtlı'` |
| 112 | `'Bekleyen BakÃƒâ€Ã‚Â±m'` | `'Bekleyen Bakım'` |
| 113 | `'Bu ay planlanmÃƒâ€Ã‚Â±Ãƒâ€¦Ã…Â¸'` | `'Bu ay planlanmış'` |
| 117 | `'PlanlanmÃƒâ€Ã‚Â±Ãƒâ€¦Ã…Â¸'` | `'Planlanmış'` |
| 129 | `'Performans ÃƒÆ'Ã‚Â¶zeti'` | `'Performans Özeti'` |
| 130 | `'AnlÃƒâ€Ã‚Â±k sistem verileri'` | `'Anlık sistem verileri'` |
| 136 | `'AylÃƒâ€Ã‚Â±k ArÃƒâ€Ã‚Â±za Trendi'` | `'Aylık Arıza Trendi'` |
| 138 | `'Son 6 aylÃƒâ€Ã‚Â±k arÃƒâ€Ã‚Â±za kayÃƒâ€Ã‚Â±tlarÃƒâ€Ã‚Â±'` | `'Son 6 aylık arıza kayıtları'` |
| 139 | `'ArÃƒâ€Ã‚Â±za'` | `'Arıza'` |
| 148 | `'ArÃƒâ€Ã‚Â±za DaÃƒâ€Ã…Â¸Ãƒâ€Ã‚Â±lÃƒâ€Ã‚Â±mÃƒâ€Ã‚Â±'` | `'Arıza Dağılımı'` |
| 149 | `'BileÃƒâ€¦Ã…Â¸en bazÃƒâ€Ã‚Â±nda analiz'` | `'Bileşen bazında analiz'` |
| 162 | `'HÃƒâ€Ã‚Â±zlÃƒâ€Ã‚Â± Eylemler'` | `'Hızlı Eylemler'` |
| 164 | `'SÃƒâ€Ã‚Â±k kullanÃƒâ€Ã‚Â±lan yÃƒÆ'Ã‚Â¶netim iÃƒâ€¦Ã…Â¸lemleri'` | `'Sık kullanılan yönetim işlemleri'` |
| 175 | `'Veriler yÃƒÆ'Ã‚Â¼klenemedi:\\n$err'` | `'Veriler yüklenemedi:\\n$err'` |
| 211 | `'Ãƒâ€Ã‚Â°statistikler & Analizler'` | `'İstatistikler & Analizler'` |
| 219 | `'YÃƒÆ'Ã‚Â¶netici Paneli'` | `'Yönetici Paneli'` |
| 252 | `'CanlÃƒâ€Ã‚Â±'` | `'Canlı'` |
| 529 | `'${rod.toY.toInt()} arÃƒâ€Ã‚Â±za'` | `'${rod.toY.toInt()} arıza'` |
| 818 | `'Rapor Ãƒâ€Ã‚Â°ndir'` | `'Rapor İndir'` |
| 825 | `'ArÃƒâ€Ã‚Â±zalar'` | `'Arızalar'` |

Yorum satırlarındaki (`// ──`) bozuk box-drawing karakterleri de temizlenecek (satır 13, 37 vb.).

---

#### [MODIFY] [fault_detail_view.dart](file:///d:/Asansor/lib/features/fault/views/fault_detail_view.dart)

**Not:** Bu dosya **CRLF** satır sonları kullanıyor. Düzeltme sırasında satır sonları LF'ye normalize edilmeli (`.gitattributes` veya editör ayarı ile).

| Satır | Bozuk Metin | Doğru Türkçe |
|---|---|---|
| 49, 77, 209 | `'ArÄ±za DetayÄ±'` | `'Arıza Detayı'` |
| 97 | `'ArÄ±za yÃ¼klenemedi'` | `'Arıza yüklenemedi'` |
| 189 | `'AsansÃ¶re Git'` | `'Asansöre Git'` |
| 236 | `'AsansÃ¶r'` | `'Asansör'` |
| 284 | `'ArÄ±za AÃ§Ä±klamasÄ±'` | `'Arıza Açıklaması'` |
| 291 | `'AÃ§Ä±klama girilmedi.'` | `'Açıklama girilmedi.'` |
| 320, 387 | `'Ã‡Ã¶zÃ¼m Notu'` | `'Çözüm Notu'` |
| 352 | `'OnarÄ±m Tarihi'` | `'Onarım Tarihi'` |
| 373 | `'Ã‡Ã¶zÃ¼m notu ekle (isteÄŸe baÄŸlÄ±)'` | `'Çözüm notu ekle (isteğe bağlı)'` |
| 389 | `'YapÄ±lan iÅŸlemleri kÄ±saca aÃ§Ä±klayÄ±nâ€¦'` | `'Yapılan işlemleri kısaca açıklayın…'` |
| 418 | `'Kaydediliyorâ€¦'` | `'Kaydediliyor…'` |
| 419 | `'ArÄ±zayÄ± Onar'` | `'Arızayı Onar'` |
| 434, 476 | `'$elevatorName DetayÄ±na Git'` | `'$elevatorName Detayına Git'` |
| 457 | `'Ä°ÅŸleniyorâ€¦'` | `'İşleniyor…'` |
| 458 | `'ArÄ±zayÄ± Yeniden AÃ§'` | `'Arızayı Yeniden Aç'` |
| 521 | `'ArÄ±zayÄ± Onar'` | `'Arızayı Onar'` |
| 523 | `'Bu arÄ±zayÄ± onarÄ±ldÄ± olarak iÅŸaretlemek...'` | `'Bu arızayı onarıldı olarak işaretlemek istediğinize emin misiniz?'` |
| 528 | `'Ä°ptal'` | `'İptal'` |
| 561 | `'ArÄ±za baÅŸarÄ±yla onarÄ±ldÄ± olarak iÅŸaretlendi.'` | `'Arıza başarıyla onarıldı olarak işaretlendi.'` |
| 598 | `'ArÄ±za yeniden aÃ§Ä±ldÄ±.'` | `'Arıza yeniden açıldı.'` |
| 655 | `'Ã‡Ã–ZÃœLDÃœ'` | `'ÇÖZÜLDÜ'` |
| 728 | `'Onarmak iÃ§in basÄ±lÄ± tutun'` | `'Onarmak için basılı tutun'` |
| 831 | `'Ã‡Ã¶zÃ¼ldÃ¼'` | `'Çözüldü'` |
| 927 | `'AsansÃ¶r bilgisi yÃ¼klenemedi'` | `'Asansör bilgisi yüklenemedi'` |

---

#### [MODIFY] [technician_management_view.dart](file:///d:/Asansor/lib/features/admin/views/technician_management_view.dart)

| Satır | Bozuk Metin | Doğru Türkçe |
|---|---|---|
| 197 | `'MÃ¼sait'` | `'Müsait'` |
| 214 | `'BugÃ¼n'` | `'Bugün'` |
| 431 | `'BugÃ¼nkÃ¼ Ä°lerleme'` | `'Bugünkü İlerleme'` |
| 439 | `'${stats.todayCompleted}/${stats.todayTotal} gÃ¶rev'` | `'${stats.todayCompleted}/${stats.todayTotal} görev'` |
| 460 | `'âœ" TÃ¼m gÃ¶revler tamamlandÄ±'` | `'✓ Tüm görevler tamamlandı'` |
| 461 | `'${stats.todayPending} gÃ¶rev bekliyor'` | `'${stats.todayPending} görev bekliyor'` |
| 469 | `'BugÃ¼n iÃ§in planlanmÄ±ÅŸ gÃ¶rev yok'` | `'Bugün için planlanmış görev yok'` |
| 509 | `'${stats.todayTotal} GÃ¶rev'` | `'${stats.todayTotal} Görev'` |
| 510 | `'GÃ¶revler'` | `'Görevler'` |
| 536, 556 | `'$name iÃ§in telefon numarasÄ± kayÄ±tlÄ± deÄŸil.'` | `'$name için telefon numarası kayıtlı değil.'` |
| 545 | `'$name: $phone â€" KopyalandÄ±'` | `'$name: $phone – Kopyalandı'` |
| 565 | `'Numara kopyalandÄ±: $phone'` | `'Numara kopyalandı: $phone'` |
| 595 | `'Bu Ay: $count Ä°ÅŸ'` | `'Bu Ay: $count İş'` |
| 721 | `'BugÃ¼n gÃ¶rev yok'` | `'Bugün görev yok'` |
| 722 | `'${stats.todayTotal} gÃ¶rev â€" ${stats.todayCompleted} tamamlandÄ±'` | `'${stats.todayTotal} görev – ${stats.todayCompleted} tamamlandı'` |
| 1027 | `'ACÄ°L'` | `'ACİL'` |
| 1028 | `'YÃœKSEK'` | `'YÜKSEK'` |
| 1030 | `'DÃœÅÃœK'` | `'DÜŞÜK'` |
| 1088 | `'HenÃ¼z teknisyen kaydÄ± yok'` | `'Henüz teknisyen kaydı yok'` |
| 1096 | `'KullanÄ±cÄ± yÃ¶netiminden teknisyen rolÃ¼ atayÄ±n.'` | `'Kullanıcı yönetiminden teknisyen rolü atayın.'` |
| 1128 | `'Veriler yÃ¼klenemedi'` | `'Veriler yüklenemedi'` |
| 1180 | `'$name iÃ§in bugÃ¼n\nplanlanmÄ±ÅŸ gÃ¶rev yok'` | `'$name için bugün\nplanlanmış görev yok'` |

---

#### [MODIFY] [pdf_service.dart](file:///d:/Asansor/lib/core/services/pdf_service.dart)

> [!WARNING]
> `pdf_service.dart` string'leri ARB'ye **taşınamaz**. `pdf` paketi Flutter `BuildContext`'ine erişemez; `AppLocalizations.of(context)` çağrılamaz. PDF string'leri encoding düzeltmesiyle sabit Türkçe olarak kalacak.

| Satır | Bozuk Metin | Doğru Türkçe |
|---|---|---|
| 534 | `'ASANSÃƒâ€"R BAKIM RAPORU'` | `'ASANSÖR BAKIM RAPORU'` |
| 593 | `'ASANSÃƒâ€"R BÃ„Â°LGÃ„Â°LERÃ„Â°'` | `'ASANSÖR BİLGİLERİ'` |
| 600 | `'Bina AdÃ„Â±'` | `'Bina Adı'` |
| 610 | `elevator.address ?? 'BelirtilmemiÃ…Å¸'` | `elevator.address ?? 'Belirtilmemiş'` |
| 630 | `'Rapor DÃƒÂ¶nemi'` | `'Rapor Dönemi'` |
| 648 | `'BAKIM GEÃƒâ€¡MÃ„Â°Ã…ÂÃ„Â°'` | `'BAKIM GEÇMİŞİ'` |
| 663 | `'TARÃ„Â°H'` | `'TARİH'` |
| 664 | `'TEKNÃ„Â°SYEN'` | `'TEKNİSYEN'` |
| 665 | `'YAPILAN Ã„Â°Ã…ÂLEMLER / NOTLAR'` | `'YAPILAN İŞLEMLER / NOTLAR'` |
| 676 | `'Bu dÃƒÂ¶nemde kayÃ„Â±t bulunamadÃ„Â±.'` | `'Bu dönemde kayıt bulunamadı.'` |
| 698 | `log.isApproved ? 'Ã¢Å"â€œ' : 'Ã¢ÂÂ³'` | `log.isApproved ? '✓' : '✗'` |
| 711 | `'Toplam kayÃ„Â±t: ${logs.length}'` | `'Toplam kayıt: ${logs.length}'` |
| 734 | `'Onaylayan / Ã„Â°mza'` | `'Onaylayan / İmza'` |
| 761 | `'OluÃ…Å¸turulma Tarihi'` | `'Oluşturulma Tarihi'` |
| 780 | `'Bu rapor otomatik olarak oluÃ…Å¸turulmuÃ…Å¸tur.'` | `'Bu rapor otomatik olarak oluşturulmuştur.'` |
| 907 | `'Ã…Âub'` | `'Şub'` |
| 913 | `'AÃ„Å¸u'` | `'Ağu'` |
| 938 | `'ArÃ„Â±zalÃ„Â±'` | `'Arızalı'` |
| 940 | `'BakÃ„Â±mda'` | `'Bakımda'` |

---

#### [MODIFY] [log_maintenance_sheet.dart](file:///d:/Asansor/lib/features/elevator/widgets/detail/log_maintenance_sheet.dart)

| Satır | Bozuk Metin | Doğru Türkçe |
|---|---|---|
| 38 | `'Oturum bilgisi alÃ„Â±namadÃ„Â±. LÃƒÂ¼tfen tekrar giriÃ…Å¸ yapÄ±n.'` | `'Oturum bilgisi alınamadı. Lütfen tekrar giriş yapın.'` |
| 79–80 | `'Ã„Â°nternet baÃ„Å¸lantÃ„Â±sÃ„Â± yok...'` | `'İnternet bağlantısı yok. Kayıt cihaza kaydedildi, bağlantı sağlandığında otomatik senkronize edilecek.'` |
| 81 | `'BakÃ„Â±m kaydÃ„Â± baÃ…Å¸arÃ„Â±yla eklendi.'` | `'Bakım kaydı başarıyla eklendi.'` |
| 115 | `'LÃƒÂ¼tfen kayÃ„Â±t tamamlanana kadar bekleyin.'` | `'Lütfen kayıt tamamlanana kadar bekleyin.'` |
| 164 | `'BakÃ„Â±m Ekle'` | `'Bakım Ekle'` |
| 172 | `'YapÃ„Â±lan bakÃ„Â±mÃ„Â± kaydedin.'` | `'Yapılan bakımı kaydedin.'` |
| 188 | `'BakÃ„Â±m NotlarÃ„Â±'` | `'Bakım Notları'` |
| 189 | `'YapÃ„Â±lan iÃ…Å¸lemleri aÃƒÂ§Ä±klayÃ„Â±n...'` | `'Yapılan işlemleri açıklayın...'` |
| 195 | `'LÃƒÂ¼tfen bakÃ„Â±m notlarÃ„Â± girin.'` | `'Lütfen bakım notları girin.'` |
| 198 | `'Notlar en az 10 karakter olmalÃ„Â±dÃ„Â±r.'` | `'Notlar en az 10 karakter olmalıdır.'` |
| 220 | `'BakÃ„Â±mÃ„Â± Kaydet'` | `'Bakımı Kaydet'` |

---

#### [MODIFY] [elevator_maintenance_history.dart](file:///d:/Asansor/lib/features/elevator/widgets/detail/elevator_maintenance_history.dart)

| Satır | Bozuk Metin | Doğru Türkçe |
|---|---|---|
| 50 | `'PDF oluÃ…Å¸turulamadÃ„Â±: ...'` | `'PDF oluşturulamadı: ...'` |
| 75 | `'BakÃ„Â±m GeÃƒÂ§miÃ…Å¸i'` | `'Bakım Geçmişi'` |
| 86 | `'PDF Rapor OluÃ…Å¸tur (Son 6 Ay)'` | `'PDF Rapor Oluştur (Son 6 Ay)'` |
| 161 | `'HenÃƒÂ¼z bakÃ„Â±m kaydÃ„Â± yok.'` | `'Henüz bakım kaydı yok.'` |
| 328 | `'Not belirtilmemiÃ…Å¸'` | `'Not belirtilmemiş'` |
| 342 | `'BEKLÃ„Â°YOR'` | `'BEKLİYOR'` |
| 394 | `'Ã…Âub'` | `'Şub'` |
| 400 | `'AÃ„Å¸u'` | `'Ağu'` |

---

### Workstream 2 — ARB Lokalizasyon Geçişi (Kapsam: Maintenance Form + Auth)

**Sprint 1 kapsamı kasıtlı olarak daraltılmıştır.** Yalnızca `maintenance_log_entry_view.dart` (temiz UTF-8, sadece buton fix'i var) ve auth ekranı string'leri bu sprintte taşınacak. Diğer mojibake'li dosyalar encoding düzeltmesi sonrasında Sprint 2–3'te kademeli olarak ARB'ye geçecek.

#### [MODIFY] [app_tr.arb](file:///d:/Asansor/lib/l10n/app_tr.arb)
#### [MODIFY] [app_en.arb](file:///d:/Asansor/lib/l10n/app_en.arb)
#### [MODIFY] [app_de.arb](file:///d:/Asansor/lib/l10n/app_de.arb)

**Eklenecek key'ler:**

```json
// app_tr.arb — mevcut 8 key'e ek olarak:
"maintenanceFormTitle": "Yeni Bakım Formu",
"maintenanceSubmitButton": "Bakımı Kaydet",
"maintenanceSavingMessage": "Kaydediliyor...",
"maintenanceSavedTitle": "Bakım Kaydedildi",
"maintenanceSavedConfirm": "Tamam",
"maintenanceSignatureError": "Lütfen hem teknisyen hem de müşteri imzasını tamamlayın.",
"maintenanceSessionError": "Oturum bilgisi alınamadı.",
"maintenanceSaveError": "Kayıt sırasında hata oluştu: {error}",
"maintenanceSavePrevention": "Lütfen kaydetme işlemi tamamlanana kadar bekleyin.",
"generalRetry": "Tekrar Dene",
"generalCancel": "İptal",
"generalError": "Hata: {error}"

// app_en.arb:
"maintenanceFormTitle": "New Maintenance Form",
"maintenanceSubmitButton": "Save Maintenance",
"maintenanceSavingMessage": "Saving...",
"maintenanceSavedTitle": "Maintenance Saved",
"maintenanceSavedConfirm": "OK",
"maintenanceSignatureError": "Please complete both the technician and customer signatures.",
"maintenanceSessionError": "Session information could not be retrieved.",
"maintenanceSaveError": "Error during save: {error}",
"maintenanceSavePrevention": "Please wait until the save operation completes.",
"generalRetry": "Retry",
"generalCancel": "Cancel",
"generalError": "Error: {error}"

// app_de.arb:
"maintenanceFormTitle": "Neues Wartungsformular",
"maintenanceSubmitButton": "Wartung speichern",
"maintenanceSavingMessage": "Wird gespeichert...",
"maintenanceSavedTitle": "Wartung gespeichert",
"maintenanceSavedConfirm": "OK",
"maintenanceSignatureError": "Bitte vervollständigen Sie beide Unterschriften.",
"maintenanceSessionError": "Sitzungsinformationen konnten nicht abgerufen werden.",
"maintenanceSaveError": "Fehler beim Speichern: {error}",
"maintenanceSavePrevention": "Bitte warten Sie, bis der Speichervorgang abgeschlossen ist.",
"generalRetry": "Erneut versuchen",
"generalCancel": "Abbrechen",
"generalError": "Fehler: {error}"
```

#### [MODIFY] [maintenance_log_entry_view.dart](file:///d:/Asansor/lib/features/maintenance/views/maintenance_log_entry_view.dart)

ARB key'leri eklenip `flutter gen-l10n` çalıştırıldıktan sonra, bu dosyadaki hard-coded string'ler `AppLocalizations.of(context)!.maintenanceFormTitle` gibi çağrılarla değiştirilecek. Bu dosya temiz UTF-8 ile yazıldığından encoding düzeltmesi gerekmez — yalnızca ARB geçişi ve buton fix'i uygulanacak.

---

### Workstream 3 — Kritik Etkileşim Hataları

#### 3a — [MODIFY] [maintenance_log_entry_view.dart](file:///d:/Asansor/lib/features/maintenance/views/maintenance_log_entry_view.dart) — Submit Buton Yapısı

**Sorun (Satır 739–770):**

```dart
// ❌ MEVCUT — İç içe interaktif widget, inner callback boş
AnimatedPressButton(
  onPressed: maintenanceState.isLoading ? null : _submit,
  child: SizedBox(
    width: double.infinity,
    height: 50,
    child: FilledButton.icon(
      onPressed: maintenanceState.isLoading ? null : () {}, // ← BOŞ!
      ...
    ),
  ),
),
```

**Düzeltme (Önerilen — Seçenek A):**

`AnimatedPressButton` widget'ını incele: eğer kendi `GestureDetector`/`InkWell`'i varsa, bunu `IgnorePointer` ile sarmala ya da gesture'ı child'a geçirecek şekilde refactor et. `FilledButton.icon`'ın `onPressed`'ini gerçek `_submit`'e bağla:

```dart
// ✅ DÜZELTME
AnimatedPressButton(
  // AnimatedPressButton yalnızca scale/press animasyonu yapar,
  // tap event'ini FilledButton yakalar
  child: FilledButton.icon(
    onPressed: maintenanceState.isLoading ? null : _submit, // ← GERÇEK
    icon: maintenanceState.isLoading
        ? const SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5, color: Colors.white,
            ),
          )
        : const Icon(Icons.check_circle_outline),
    label: Text(
      maintenanceState.isLoading ? 'Kaydediliyor...' : 'Bakımı Kaydet',
      style: textTheme.titleMedium?.copyWith(color: colors.surface),
    ),
    style: FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, 50),
      backgroundColor: colors.primary,
      foregroundColor: colors.surface,
    ),
  ),
),
```

> [!NOTE]
> Eğer `AnimatedPressButton`'ın kendi gesture katmanı çıkarılamıyorsa (kütüphane widget'ı ise), **Seçenek B:** `AnimatedPressButton`'ı tamamen kaldır, direkt `FilledButton.icon` kullan. Animasyon kaybı ihmal edilebilir düzeyde.

---

#### 3b — [MODIFY] [fault_detail_view.dart](file:///d:/Asansor/lib/features/fault/views/fault_detail_view.dart) — Long-Press Kaldırma

**Sorun:** Satır 728'deki durum header'ı yalnızca long-press ile aksiyon tetikliyor. `'Onarmak için basılı tutun'` tooltip'inin varlığı, bu sorunu tasarım aşamasında fark eden ekibin bunu telafi etmeye çalıştığının göstergesi.

**Karar: Long-press tamamen kaldırılacak, yerine duruma göre değişen görünür butonlar konacak.**

Gerekçe: Arızayı onar/yeniden aç, bu uygulamanın birincil iş aksiyonu. WCAG 2.5.1'e göre primary action'lar tek dokunuşla erişilebilir olmak zorunda. Confirm dialog zaten ikinci güvenlik katmanı görevi görüyor — long-press gereksiz.

**Düzeltme:**

```dart
// 1. Header'daki GestureDetector/InkWell long-press handler'ını KALDIR
// 2. Satır 728'deki 'Onarmak için basılı tutun' tooltip'ini KALDIR
// 3. Aksiyon alanına aşağıdaki butonları EKLE:

// Arıza durumuna göre koşullu aksiyon butonu:
if (fault.status != FaultStatus.resolved)
  FilledButton.icon(
    onPressed: _onResolvePressed, // mevcut confirm dialog'u tetikler
    icon: const Icon(Icons.check_circle_outline),
    label: const Text('Arızayı Onar'),
    style: FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, 48),
    ),
  )
else
  OutlinedButton.icon(
    onPressed: _onReopenPressed, // mevcut confirm dialog'u tetikler
    icon: const Icon(Icons.refresh_rounded),
    label: const Text('Arızayı Yeniden Aç'),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(double.infinity, 48),
    ),
  ),
```

> [!NOTE]
> Mevcut confirm dialog'lar (`'Bu arızayı onarıldı olarak işaretlemek istediğinize emin misiniz?'`) **korunacak** — long-press kaldırılıyor, doğrulama akışı aynı kalıyor.

---

### Workstream 4 — CI/CD İyileştirmeleri

#### [MODIFY] [flutter_ci.yml](file:///d:/Asansor/.github/workflows/flutter_ci.yml)

`flutter analyze` adımından **önce** mojibake kontrolü ekle:

```yaml
- name: Check for mojibake (corrupted Turkish characters)
  run: |
    if grep -rn --include="*.dart" -P "[\xc3][\x80-\xbf]|[\xc4][\x80-\xbf]|[\xc5][\x80-\xbf]" lib/; then
      echo "❌ Mojibake detected. Fix encoding before committing."
      exit 1
    fi
    echo "✅ No mojibake found."
```

#### [MODIFY] [test.yml](file:///d:/Asansor/.github/workflows/test.yml)

Mevcut `test.yml`'de tespit edilen 3 kritik sorun düzeltilecek:

```yaml
# 1. Workflow adını değiştir (flutter_ci.yml ile çakışıyor)
name: Flutter Test & Format  # "Flutter CI" yerine

# 2. .env dummy dosyası ekle (şu anda eksik — build başarısız olur)
- name: Create dummy .env file
  run: touch .env

# 3. dart format satırını geçici olarak comment'e al (mojibake fix tamamlanana kadar)
# - run: dart format --output=none --set-exit-if-changed .
# Mojibake düzeltmeleri push edildikten SONRA bu satır aktif edilecek
```

> [!CAUTION]
> `dart format --set-exit-if-changed .` komutu, mojibake içeren dosyaları format hatası olarak algılıyor ve CI'ı başarısız yapıyor. Bu satır **önce encoding düzeltilir, sonra aktif edilir**.

---

## Uygulama Sıralaması

```
Gün 1 AM  → admin_statistics_dashboard.dart (en ağır — çift/üçlü mojibake)
Gün 1 PM  → fault_detail_view.dart (CRLF → LF normalizasyonu dahil)
Gün 2 AM  → technician_management_view.dart + pdf_service.dart
Gün 2 PM  → log_maintenance_sheet.dart + elevator_maintenance_history.dart
Gün 3 AM  → ARB key'leri ekle (maintenance + auth) + flutter gen-l10n çalıştır
Gün 3 PM  → maintenance_log_entry_view.dart: string'leri ARB çağrılarıyla değiştir
             + submit buton yapısını düzelt (inner callback → _submit)
Gün 4 AM  → fault_detail_view.dart: long-press kaldır, görünür aksiyon butonları ekle
Gün 4 PM  → test.yml sorunlarını düzelt + CI mojibake kontrolü ekle
             + flutter analyze + flutter test + dart format → PR aç
```

---

## Doğrulama Planı

### Otomatik Testler

```bash
# 1. Mojibake taraması (sıfır sonuç beklenir)
grep -rn --include="*.dart" -P "[\xc3][\x80-\xbf]|Ã|Ä±|Ã¼" lib/

# 2. Lokalizasyon derleme
flutter gen-l10n

# 3. Statik analiz
flutter analyze

# 4. Mevcut test suite
flutter test

# 5. Format kontrolü (yalnızca mojibake fix tamamlandıktan sonra)
dart format --output=none --set-exit-if-changed .
```

### Manuel Doğrulama

| Ekran | Kontrol Noktası |
|---|---|
| Arıza Detayı | Sayfa başlığı, butonlar, durum etiketleri doğru Türkçe |
| Teknisyen Yönetimi | Durum etiketleri, snackbar mesajları, görev sayaçları doğru |
| Admin İstatistik | Tüm metrik kartları, grafik etiketleri, hızlı eylemler doğru |
| Bakım Geçmişi | Bölüm başlığı, PDF butonu, boş durum mesajı doğru |
| Bakım Formu Submit | Tek tıklamada `_submit` tetikleniyor, loading spinner doğru çalışıyor |
| Bakım Formu Submit | Ekran okuyucu (TalkBack/VoiceOver) butonu doğru okuyor |
| Arıza Detayı Aksiyon | Long-press **yok**, görünür `FilledButton`/`OutlinedButton` ile aksiyon yapılabiliyor |
| Arıza Detayı Aksiyon | Confirm dialog çalışıyor (doğrulama akışı bozulmamış) |
| PDF Oluştur | Başlık, tablo header'ları, ay isimleri, durum etiketleri doğru Türkçe |
| CI Pipeline | Mojibake check adımı yeşil, `dart format` adımı aktif ve geçiyor |

---

## Kabul Kriterleri

- [ ] `grep -rn --include="*.dart" -P "[\xc3][\x80-\xbf]|Ã|Ä±|Ã¼" lib/` **sıfır sonuç** döndürüyor
- [ ] Manuel PDF oluşturma testi: başlıklar, tablo header'ları, ay isimleri doğru Türkçe
- [ ] `app_tr.arb`, `app_en.arb`, `app_de.arb`'de maintenance ile ilgili 12 yeni key mevcut (3 dil × 12)
- [ ] `flutter gen-l10n` hatasız tamamlanıyor
- [ ] Bakım formu submit butonuna tıklandığında yalnızca `_submit` çağrılıyor (iç içe boş callback yok)
- [ ] Fault detail'de `GestureDetector` long-press handler **kaldırıldı**, yerine `FilledButton`/`OutlinedButton` var
- [ ] Arıza onar/yeniden aç confirm dialog akışı bozulmadan çalışıyor
- [ ] `flutter analyze` sıfır hata ile tamamlanıyor
- [ ] `test.yml` isim çakışması düzeltildi, `.env` adımı eklendi, `dart format` adımı aktif
- [ ] CI pipeline'a mojibake kontrolü eklendi ve tüm değişiklikler push edildikten sonra yeşil
