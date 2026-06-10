# DevOps Implementation Plan

Kaynaklar:

- `doc/comprehensive_audit_report.md`
- `yapilacaklar2.md` DEVOPs bolumu
- Mevcut workflow'lar: `.github/workflows/flutter_ci.yml`, `.github/workflows/supabase_rls_test.yml`

## Mevcut Durum

- Flutter SDK versiyonu `flutter-version: "3.41.6"` ile pinlenmis durumda.
- CI workflow tekrari buyuk olcude giderilmis: `test.yml` artik yok, ana Flutter CI `.github/workflows/flutter_ci.yml`.
- Secret scanning `gitleaks/gitleaks-action@v2` ile Flutter CI icine eklenmis.
- Android release signing Gradle tarafinda `key.properties` veya CI environment degiskenleri uzerinden tanimli.
- Supabase RLS testleri icin ayri `.github/workflows/supabase_rls_test.yml` mevcut.

Kalan DevOps isleri:

1. Android/iOS build job eklemek.
2. Dev/staging/prod build flavor altyapisini kurmak.
3. Supabase migration validation'i CI'da guvenilir hale getirmek.
4. Uzun vadede crash reporting ve store release automation eklemek.

## Hedef CI Kapilari

Her pull request su kapilardan gecmeli:

- `dart format --set-exit-if-changed`
- `flutter analyze`
- `flutter test`
- Secret scan
- Edge Function unit testleri
- Android release derleme dogrulamasi
- iOS release derleme dogrulamasi, ilk asamada codesign olmadan
- Supabase migration dry-run veya local migration reset
- pgTAP/RLS testleri

`main` veya release branch icin ek kapilar:

- Android signed AAB artifact
- iOS signed IPA, Apple certificate/provisioning hazir oldugunda
- Crash reporting sembol/dSYM mapping upload
- Store release workflow

## Asama 1 - CI Build Job

Amac: Kod testten gecse bile release build'in bozulmasini engellemek.

### Android

Uygulama icin oncelikli artifact APK degil AAB olmali; Play Store hedefi icin `appbundle` daha dogru gate'tir.

Yapilacaklar:

- `.github/workflows/flutter_ci.yml` icine Android build job ekle.
- Job `flutter_ci` test job'una bagli calissin: `needs: flutter_ci`.
- Java 17 ve Flutter setup adimlarini tekrar kullan veya reusable workflow'a tasimayi sonraki refactor olarak birak.
- CI secret'larini tanimla:
  - `ANDROID_KEYSTORE_BASE64`
  - `KEYSTORE_PASSWORD`
  - `KEY_PASSWORD`
  - `KEY_ALIAS`
- Build oncesi keystore'u workspace'e decode et:
  - Hedef: `android/app/upload-keystore.jks`
  - `KEYSTORE_PATH` env: `android/app/upload-keystore.jks`
- Build komutu:
  - Flavor yokken gecici komut:
    - `flutter build appbundle --release --dart-define=SUPABASE_URL=${{ secrets.STAGING_SUPABASE_URL }} --dart-define=SUPABASE_ANON_KEY=${{ secrets.STAGING_SUPABASE_ANON_KEY }}`
  - Flavor eklendikten sonra kalici komut:
    - `flutter build appbundle --release --flavor staging --target lib/main.dart --dart-define=APP_ENV=staging --dart-define=SUPABASE_URL=${{ secrets.STAGING_SUPABASE_URL }} --dart-define=SUPABASE_ANON_KEY=${{ secrets.STAGING_SUPABASE_ANON_KEY }}`
- Artifact upload ekle:
  - `build/app/outputs/bundle/**/*.aab`

Kabul kriterleri:

- PR acildiginda Android release build derleniyor.
- Signing secret eksikse job acik ve anlasilir hata veriyor.
- Artifact CI sonucundan indirilebiliyor.

### iOS

Ilk hedef iOS kodunun release modda derlenebildigini dogrulamak. Signed IPA icin Apple Developer certificate, provisioning profile ve keychain kurulumu ayri release isidir.

Yapilacaklar:

- `.github/workflows/flutter_ci.yml` icine macOS runner'li `ios_build` job ekle.
- Job sadece PR ve push'ta compile gate olarak calissin.
- Build komutu:
  - Flavor yokken:
    - `flutter build ios --release --no-codesign --dart-define=SUPABASE_URL=${{ secrets.STAGING_SUPABASE_URL }} --dart-define=SUPABASE_ANON_KEY=${{ secrets.STAGING_SUPABASE_ANON_KEY }}`
  - Flavor eklendikten sonra:
    - `flutter build ios --release --no-codesign --flavor staging --target lib/main.dart --dart-define=APP_ENV=staging --dart-define=SUPABASE_URL=${{ secrets.STAGING_SUPABASE_URL }} --dart-define=SUPABASE_ANON_KEY=${{ secrets.STAGING_SUPABASE_ANON_KEY }}`

Kabul kriterleri:

- iOS release compile PR'da calisiyor.
- Codesign olmadigi icin store-ready IPA iddiasi yok; sadece compile gate.
- Apple signing hazirlanmadan `flutter build ipa` PR gate'e eklenmiyor.

## Asama 2 - Build Flavor Altyapisi

Amac: dev/staging/prod ortamlarini birbirinden ayirmak ve yanlis Supabase/Firebase hedeflerine build alinmasini engellemek.

### Flutter runtime config

Yapilacaklar:

- `lib/core/constants/supabase_constants.dart` mevcut `--dart-define` modelini korusun.
- Yeni `APP_ENV` compile-time degeri ekle:
  - `dev`
  - `staging`
  - `prod`
- `lib/core/config/app_environment.dart` gibi kucuk bir config sinifi ekle.
- `SupabaseConstants.validate()` sadece URL/key degil, `APP_ENV` degerini de validate etsin.
- Ornek env dosyalari ekle:
  - `.env.dev.example`
  - `.env.staging.example`
  - `.env.prod.example`
- Gercek `.env.*` dosyalari `.gitignore` altinda kalmali.

Kabul kriterleri:

- Eksik `SUPABASE_URL`, `SUPABASE_ANON_KEY` veya gecersiz `APP_ENV` app startup'ta net hata veriyor.
- CI dummy `.env` yerine explicit `--dart-define` kullaniyor.

### Android flavors

Yapilacaklar:

- `android/app/build.gradle.kts` icine flavor dimension ekle:
  - `flavorDimensions += "env"`
- Product flavor'lar:
  - `dev`: `applicationIdSuffix = ".dev"`, app name `Asansor Dev`
  - `staging`: `applicationIdSuffix = ".staging"`, app name `Asansor Staging`
  - `prod`: suffix yok, app name `Asansor`
- Flavor bazli Firebase config ihtiyaci varsa dosya yapisi:
  - `android/app/src/dev/google-services.json`
  - `android/app/src/staging/google-services.json`
  - `android/app/src/prod/google-services.json`
- Bu dosyalar secret iceriyorsa repoya konmamali; CI'da base64 secret olarak uretilmeli.

Kabul kriterleri:

- `flutter build appbundle --release --flavor dev` calisiyor.
- `flutter build appbundle --release --flavor staging` calisiyor.
- `flutter build appbundle --release --flavor prod` calisiyor.
- Dev/staging paketleri prod paketin ustune yazilmiyor.

### iOS flavors

Yapilacaklar:

- Xcode schemes/configurations ekle:
  - `dev`
  - `staging`
  - `prod`
- Bundle identifier ayrimi:
  - `com.asansor.asansor.dev`
  - `com.asansor.asansor.staging`
  - `com.asansor.asansor`
- Flavor bazli `GoogleService-Info.plist` stratejisi belirle.
- CI ilk asamada `--no-codesign` ile staging scheme'i derlesin.

Kabul kriterleri:

- `flutter build ios --release --no-codesign --flavor staging` calisiyor.
- Prod bundle identifier sadece prod flavor'da kullaniliyor.

## Asama 3 - Supabase Migration Validation

Amac: Migration dosyalari merge edilmeden once uygulanabilirlik, RLS testleri ve policy regresyonlari CI'da yakalansin.

Mevcut durum:

- `.github/workflows/supabase_rls_test.yml` Supabase CLI'yi `latest` ile kuruyor.
- `supabase start` ve `supabase test db` calisiyor.

Yapilacaklar:

- Supabase CLI versiyonunu pinle:
  - Ornek: `version: 2.x.x`
- Workflow'a migration validation adimi ekle:
  - Tercih edilen lokal dogrulama: `supabase db reset`
  - Ardindan: `supabase test db`
- Remote dry-run istenirse ayri ve protected job olarak ekle:
  - `supabase db push --dry-run`
  - Sadece `main` veya manuel `workflow_dispatch`
  - `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_ID`, `SUPABASE_DB_PASSWORD` secrets ile
- Migration dosyalarinda forbidden fallback kontrolu ekle:
  - `local-dev-secret-key`
  - `<YOUR_ANON_KEY>`
  - service account private key marker'lari
- Supabase local runtime cache'i ekle veya job suresini olcerek gerekirse optimize et.

Kabul kriterleri:

- Yeni migration siradan temiz DB'ye uygulanabiliyor.
- RLS/pgTAP testleri migration sonrasinda geciyor.
- Bilinen placeholder veya fallback secret tekrar eklenirse CI fail oluyor.
- Supabase CLI `latest` yuzunden beklenmedik davranis degisikligi riski kalkiyor.

## Asama 4 - Release Observability

Bu asama `yapilacaklar2.md` Faz 3'teki crash reporting maddesiyle baglantili.

Yapilacaklar:

- Crash reporting secimi yap:
  - Firebase Crashlytics, Firebase zaten kullanildigi icin en dusuk entegrasyon maliyetli secenek.
  - Sentry daha guclu release/environment filtreleme sunar.
- `APP_ENV`, app version, build number ve git SHA crash context'e eklensin.
- CI release build sonrasinda mapping/dSYM upload adimi eklensin.
- Production build'de debug/token loglari kapali kalsin.

Kabul kriterleri:

- Staging ve prod crash'leri ayri gorunuyor.
- Release artifact ile crash sembolleri ayni build numarasina bagli.

## Asama 5 - Store Release Automation

Bu asama signed build pipeline stabil olduktan sonra yapilmali.

Yapilacaklar:

- Android:
  - `main` veya `release/*` branch'te signed AAB uret.
  - Google Play service account secret'i GitHub Actions secret olarak ekle.
  - Internal testing track'e otomatik upload ekle.
- iOS:
  - Apple certificate/provisioning profile/keychain setup.
  - App Store Connect API key secret'lari.
  - TestFlight upload.
- Release workflow manuel tetiklenebilir olsun:
  - `workflow_dispatch`
  - input: `environment`, `version`, `build_number`

Kabul kriterleri:

- Staging release manuel tetiklenebiliyor.
- Prod release manuel onay olmadan store'a gitmiyor.
- Artifact, version, build number ve commit SHA izlenebilir.

## Onerilen Uygulama Sirasi

1. `.github/workflows/flutter_ci.yml` icine Android AAB ve iOS `--no-codesign` build job'larini ekle.
2. Build job'larda explicit staging `--dart-define` secrets kullan; dummy `.env` bagimliligini azalt.
3. `APP_ENV` validation ve example env dosyalarini ekle.
4. Android product flavor'larini ekle.
5. iOS scheme/flavor yapisini ekle.
6. CI build komutlarini `--flavor staging` kullanacak sekilde guncelle.
7. Supabase CLI versiyonunu pinle.
8. `supabase db reset` + `supabase test db` migration validation kapisini netlestir.
9. Forbidden secret/fallback grep kontrolunu migration workflow'una ekle.
10. Crash reporting secimini yap ve staging'de aktif et.
11. Signed release workflow'u Android icin, sonra iOS icin ayri manuel workflow olarak ekle.

## Riskler ve Notlar

- Android release signing CI secret'lari hazir degilse release build job fail eder. Gecici olarak unsigned debug build gate eklemek production riskini cozmez; asil hedef signed release/AAB olmalidir.
- iOS signed IPA icin Apple hesabina ve certificate/provisioning setup'ina ihtiyac var. Bu hazir degilse PR gate sadece `--no-codesign` compile validation yapmali.
- Flavor eklenmeden once CI build job'lari staging Supabase secret'lari ile calismali; prod secret PR job'larinda kullanilmamali.
- Supabase `latest` CLI kullanimi audit'teki floating toolchain problemine benzer risk tasir; CLI versiyonu da pinlenmeli.
- Secret scanning zaten var, ancak migration ve function dosyalari icin placeholder/fallback kontrolu yine de eklenmeli.
