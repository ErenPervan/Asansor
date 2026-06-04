# Asansör Projesi — GitHub Issues Model Eşleştirme Kılavuzu (Güncellenmiş)

Bu döküman, projedeki aktif GitHub issue'larının (Issues #4 - #12) zorluk dereceleri, mimari riskleri ve mantıksal derinliklerine göre, elinizde bulunan spesifik yapay zeka modelleriyle eşleştirme kılavuzudur.

---

## Elinizdeki Model Sınıfları ve Rolleri

### 🧠 Üst Düzey Düşünme & Akıl Yürütme Modelleri (Thinking / Reasoning)
- **Modeller:** `Claude Opus 4.6 (Thinking)`, `Claude Sonnet 4.6 (Thinking)`
- **Kullanım Alanı:** En karmaşık mimari değişiklikler, yarış durumları (race conditions), şifreleme/güvenlik, durum yönetimi (state lifecycle) ve kapsamlı mantık tasarımı.

### 🏢 Profesyonel Kodlama & Entegrasyon Modelleri (Pro / Mid-High)
- **Modeller:** `Gemini 3.1 Pro (High)`, `Gemini 3.1 Pro (Low)`, `GPT-OSS 120B (Medium)`
- **Kullanım Alanı:** Düzen ve rendering dönüşümleri, orta-yüksek karmaşıklıklı iş mantığı, entegrasyonlar ve API adaptasyonları.

### ⚡ Hızlı & Geniş Kapsamlı Operasyon Modelleri (Flash / Fast)
- **Modeller:** `Gemini 3.5 Flash (High)`, `Gemini 3.5 Flash (Medium)`, `Gemini 3.5 Flash (Low)`
- **Kullanım Alanı:** Şablon bazlı kodlama, birim/widget test yazımı, mekanik refactoring (toplu bul-değiştir), erişilebilirlik etiketlemeleri ve stil düzenlemeleri.

---

## Aktif Görevler İçin Model Eşleştirme Tablosu

| Issue No | Görev / Sprint Adı | Önerilen Birincil Model | Alternatif Model | Detaylı Rasyonel |
|:---:|---|---|---|---|
| **#4** | Sprint 2: Navigasyon ve Asenkron State Standartları | `Claude Sonnet 4.6 (Thinking)` | `Gemini 3.1 Pro (High)` | `StatefulShellRoute` navigasyon yapısına geçiş ve Riverpod asenkron state sarmalayıcısı (`AppAsyncView`) tasarımı, yönlendirme (routing) mantığı için derin kod okuma kabiliyeti gerektirir. |
| **#5** | Sprint 3: Tasarım Sistemi (Design System) ve Tema | `Gemini 3.1 Pro (High)` | `Gemini 3.5 Flash (High)` | Ortak widget tasarımı için `Gemini 3.1 Pro` kullanılırken, forced light mode'un kaldırılması ve font spacing düzenleme gibi mekanik işler için `Gemini 3.5 Flash` idealdir. |
| **#6** | Sprint 4: Performans İyileştirmeleri | `Gemini 3.1 Pro (High)` | `Gemini 3.5 Flash (Medium)` | `shrinkWrap: true` listelerin `Sliver` yapılarına dönüştürülmesi render performansı bilgisi gerektirdiğinden Pro sınıfı uygundur. Görsel wrapper değişimleri Flash model ile yapılabilir. |
| **#7** | Sprint 5: Erişilebilirlik (A11y) | `Gemini 3.5 Flash (High)` | `Gemini 3.5 Flash (Medium)` | Tooltip, `Semantics` ekleme ve buton boyutlarını 48x48 piksel yapma gibi şablon tabanlı a11y standartları Flash sınıfı ile son derece hızlı çözülür. |
| **#8** | Push Notification UX & Routing | `Claude Opus 4.6 (Thinking)` | `Claude Sonnet 4.6 (Thinking)` | Auth-notification yarış durumu (race condition), deep-link yönetimi ve sunucu tarafı fan-out tasarımı en yüksek akıl yürütme (`Thinking`) seviyesini gerektiren kritik bir konudur. |
| **#9** | Deep Link & URL Scheme UX | `Claude Sonnet 4.6 (Thinking)` | `Gemini 3.1 Pro (High)` | `AndroidManifest.xml` ve `Info.plist` intent filtreleri ile Flutter rotalarının eşleştirilmesi ve invalid ID fallback senaryoları için yüksek reasoning gerekir. |
| **#10** | Riverpod State & Hive Key Migration | `Claude Opus 4.6 (Thinking)` | `Claude Sonnet 4.6 (Thinking)` | Hive AES şifreleme anahtarı kurtarma (Graceful Recovery UX) ve Riverpod state/sign-out temizleme işlemleri kritik güvenlik-durum yönetimi içerdiğinden Opus için en uygun görevdir. |
| **#11** | Role/Capability Matrix Geçişi | `Claude Sonnet 4.6 (Thinking)` | `Gemini 3.5 Flash (High)` | Yetki matrisinin ve capability enum mimarisinin tasarlanması `Claude Sonnet (Thinking)` ile yapılmalı, UI genelindeki toplu refactor (değiştirme) adımı ise `Gemini 3.5 Flash` ile yürütülmelidir. |
| **#12** | Widget & Golden Testing Baseline | `Gemini 3.5 Flash (High)` | `Gemini 3.1 Pro (Low)` | Golden testler ve navigasyon widget testleri şablon bazlıdır. Mock sınıflarının (mocktail) oluşturulması ve test suitlerinin doldurulması hızlı modellerle yapılabilir. |

---

## Stratejik İş Akışı Önerisi
- **Mimari Tasarım:** Herhangi bir sprinte başlamadan önce, projenin o anki durumunu verip `Claude Opus 4.6 (Thinking)` veya `Claude Sonnet 4.6 (Thinking)` modeline teknik analiz yaptırın.
- **Parçalı Görev Paylaşımı:** İş mantığı/altyapı yazımını `Gemini 3.1 Pro (High)`'a yaptırın.
- **Toplu Uygulama & Test:** Yazılan altyapının tüm sayfalara uygulanması ve test suite'lerinin eklenmesi aşamasında `Gemini 3.5 Flash (High)` modelini devreye sokarak süreci hızlandırın.
