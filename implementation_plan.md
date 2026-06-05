# Sprint: Push Notification UX & Routing Architecture — Implementation Plan

**GitHub Issue:** [#8 Sprint: Push Notification UX & Routing Architecture](https://github.com/ErenPervan/Asansor/issues/8)  
**Hazırlanma Tarihi:** 2026-06-05  
**Tahmini Efor:** 2-3 iş günü

---

## Bağlam & Mevcut Durum Analizi

Mevcut anlık bildirim (Push Notification) altyapısının iyileştirilmesi gereken 6 temel mimari ve kullanıcı deneyimi (UX) alanı bulunmaktadır:

1. **Giriş-Bildirim Yarış Durumu (Race Condition):** Uygulama kapalıyken (terminated state) gelen bir bildirim tıklandığında (Soğuk Başlangıç - State 1), uygulama başlar başlamaz `handleInitialMessage` üzerinden bir sayfaya yönlendirme yapmaya çalışmaktadır. Ancak bu esnada `appAuthStateProvider` durumu henüz `AuthStatus.profileLoading` aşamasındadır. `GoRouter`'ın `redirect` mekanizması kullanıcıyı otomatik olarak `/loading` sayfasına ve profil yüklendiğinde de `/` (Ana Sayfa) konumuna yönlendirdiği için tıklanan bildirimdeki hedef sayfa (Örn: `/elevator/{id}`) kaybolmaktadır.
2. **Rol Bazlı Yönlendirme Eksikliği:** Bildirim tıklama yönlendirmeleri kullanıcının rolünden bağımsızdır. Örneğin, `task_assigned` (görev atandı) bildirimi geldiğinde teknisyenler ana sayfadaki görev listesine (`/`) gitmeliyken, yöneticiler (admin) ilgili atama detayına veya takvime (`/admin/calendar`) gitmelidir.
3. **Güvenliksiz Client-Side Fanout:** `notifyAllAdmins` fonksiyonu istemci tarafında (client-side) tüm yöneticilerin ID'lerini çekmekte ve her biri için ayrı ayrı HTTP isteği göndererek toplu bildirim yapmaktadır. Bu hem yavaş hem de istemci tarafında çoklu istek yönetimi gerektiren güvensiz bir yaklaşımdır. Sunucu tarafında fanout (server-side fanout) yapılması gerekmektedir.
4. **Tek Kanal Android Bildirimleri:** Tüm bildirimler (arıza, görev vb.) tek bir Android Notification Channel üzerinden gitmektedir. Kullanıcıların arıza bildirimleri ile görev atama bildirimlerini sistem ayarlarından ayrı ayrı sessize alabilmesi veya önceliklendirebilmesi için çoklu kanal desteği şarttır.
5. **Tip Güvensiz Payload Yapısı:** `handleNotificationClick` metodu ham `Map<String, dynamic>` veri yapısı üzerinden çalışmaktadır. Bu durum runtime hatalarına ve karmaşık `if-else` bloklarına yol açmaktadır.
6. **Agresif İzin İsteği (UX Antipattern):** Uygulama ilk açıldığında doğrudan OS bildirim izni istemektedir. Kullanıcıya bildirimlerin ona ne fayda sağlayacağını anlatan bir **Gerekçe (Rationale) Ekranı** göstermeden izin istenmesi red oranını artırmaktadır.

---

## Önerilen Değişiklikler

---

### Workstream 1 — Tip Güvenli Payload ve Rol Bazlı Routing Modeli

#### [NEW] [notification_payload.dart](file:///d:/Asansor/lib/core/models/notification_payload.dart)

Tüm bildirim veri tiplerini sarmalayan ve Dart 3 `sealed class` yapısını kullanan tip güvenli bir model dosyası oluşturulacak.

```dart
import '../enums/app_enums.dart';

sealed class NotificationPayload {
  const NotificationPayload();

  factory NotificationPayload.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    final elevatorId = json['elevator_id'] as String?;
    final route = json['route'] as String?;

    if (type == 'task_assigned') {
      return const TaskAssignedPayload();
    } else if (type == 'task_completed') {
      return TaskCompletedPayload(
        elevatorId: elevatorId ?? '',
        route: route ?? '',
      );
    } else if (elevatorId != null && elevatorId.isNotEmpty) {
      return ElevatorDetailPayload(elevatorId: elevatorId);
    } else if (route != null && route.isNotEmpty) {
      if (route.startsWith('/fault/')) {
        final faultId = route.substring('/fault/'.length);
        return FaultDetailPayload(faultId: faultId);
      }
      return ExplicitRoutePayload(route: route);
    } else {
      return const FallbackPayload();
    }
  }

  Map<String, dynamic> toJson();
}

class TaskAssignedPayload extends NotificationPayload {
  const TaskAssignedPayload();
  @override
  Map<String, dynamic> toJson() => {'type': 'task_assigned'};
}

class TaskCompletedPayload extends NotificationPayload {
  final String elevatorId;
  final String route;

  const TaskCompletedPayload({required this.elevatorId, required this.route});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'task_completed',
        'elevator_id': elevatorId,
        'route': route,
      };
}

class ElevatorDetailPayload extends NotificationPayload {
  final String elevatorId;
  const ElevatorDetailPayload({required this.elevatorId});

  @override
  Map<String, dynamic> toJson() => {'elevator_id': elevatorId};
}

class FaultDetailPayload extends NotificationPayload {
  final String faultId;
  const FaultDetailPayload({required this.faultId});

  @override
  Map<String, dynamic> toJson() => {'route': '/fault/$faultId'};
}

class ExplicitRoutePayload extends NotificationPayload {
  final String route;
  const ExplicitRoutePayload({required this.route});

  @override
  Map<String, dynamic> toJson() => {'route': route};
}

class FallbackPayload extends NotificationPayload {
  const FallbackPayload();
  @override
  Map<String, dynamic> toJson() => {};
}

/// Rol bazlı hedeflenen yönlendirme rotasını belirler.
String determineDestination(NotificationPayload payload, UserRole? role) {
  return switch (payload) {
    TaskAssignedPayload() => switch (role) {
        UserRole.technician => '/', // Teknisyen için ana sayfa (görev listesi)
        UserRole.admin => '/admin/calendar', // Yönetici için takvim ekranı
        _ => '/',
      },
    TaskCompletedPayload(:final route) => switch (role) {
        UserRole.admin => route.isNotEmpty ? route : '/admin/master-calendar',
        _ => '/',
      },
    ElevatorDetailPayload(:final elevatorId) => '/elevator/$elevatorId',
    FaultDetailPayload(:final faultId) => '/fault/$faultId',
    ExplicitRoutePayload(:final route) => route,
    FallbackPayload() => '/',
  };
}
```

---

### Workstream 2 — Giriş/Bildirim Yarış Durumu (Race Condition) Çözümü

#### [MODIFY] [notification_service.dart](file:///d:/Asansor/lib/core/services/notification_service.dart)

- `isAuthorized` ve `userRole` durumlarını tutan değişkenler eklenecek.
- `_pendingRoute` adlı bir değişken ile henüz yetkilendirilmemiş durumdayken gelen bildirimlerin hedefleri geçici olarak saklanacak.
- `handleNotificationClick` metodu güncellenerek:
  - Eğer kullanıcı giriş yapmış durumdaysa (`isAuthorized == true`) yönlendirmeyi hemen gerçekleştirecek.
  - Eğer giriş yapılmamışsa (`isAuthorized == false`), rotayı `_pendingRoute` içine yazıp bekletecek.
- `consumePendingRoute()` metodu ile saklanan rota okunup sıfırlanacak.

```dart
  bool isAuthorized = false;
  UserRole? userRole;
  String? _pendingRoute;

  /// Bekleyen rotayı okur ve tüketir (siler).
  String? consumePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  void handleNotificationClick(Map<String, dynamic>? data) {
    if (data == null) return;

    final payload = NotificationPayload.fromJson(data);
    final destination = determineDestination(payload, userRole);

    if (isAuthorized) {
      _scheduleNavigation(destination);
    } else {
      debugPrint('[FCM] App not authorized yet. Storing pending route: $destination');
      _pendingRoute = destination;
    }
  }
```

#### [MODIFY] [app_router.dart](file:///d:/Asansor/lib/core/router/app_router.dart)

- `RouterNotifier` sınıfı `appAuthStateProvider`'ı dinlediğinde, `isAuthorized` ve `userRole` değerlerini `NotificationService`'e aktaracak.
- `GoRouter` `redirect` callback'i içerisinde, durum `AuthStatus.authorized` olduğunda ve kullanıcı `/loading` veya `/login` aşamasındayken bekleyen bir rota olup olmadığı denetlenecek:
  - Varsa, o rotaya (`pendingRoute`) yönlendirilecek ve bekleyen veri sıfırlanacak.
  - Yoksa, normal akışta olduğu gibi `/` (veya role-specific default) sayfasına gidilecek.

```dart
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  ProviderSubscription? _subscription;

  RouterNotifier(this._ref) {
    _subscription = _ref.listen<AuthStateModel>(
      appAuthStateProvider,
      (previous, current) {
        // Durumları NotificationService'e aktar
        NotificationService.instance.isAuthorized = current.status == AuthStatus.authorized;
        NotificationService.instance.userRole = current.role;
        notifyListeners();
      },
      fireImmediately: true,
    );
  }
  // ...
}
```

`redirect` içerisindeki düzeltme:
```dart
        case AuthStatus.authorized:
          // Kullanıcı giriş yapmış veya loading ekranından çıkıyorsa
          if (isOnLoginPage || isOnLoadingPage) {
            final pendingRoute = NotificationService.instance.consumePendingRoute();
            if (pendingRoute != null) {
              debugPrint('[Router] Redirecting to pending notification route: $pendingRoute');
              return pendingRoute;
            }
            return '/';
          }
```

---

### Workstream 3 — Sunucu Tarafı Fanout (Server-Side Fanout) ve Supabase Edge Function Güncellemesi

#### [MODIFY] [send-notification/index.ts](file:///d:/Asansor/supabase/functions/send-notification/index.ts)

Edge function payload formatına `to_role` parametresi eklenecek. Rol bazlı istek geldiğinde veritabanından o role sahip tüm profiller tek bir SQL sorgusu ile sunucu tarafında çekilecek ve FCM token'larına bildirim gönderilecek.

```typescript
    else if ((reqBody.to_user_id || reqBody.to_role) && reqBody.title && reqBody.body) {
      // Direct App Call — verify auth token
      const authHeader = req.headers.get("Authorization");
      if (!authHeader || !authHeader.startsWith("Bearer ")) {
        return new Response(
          JSON.stringify({ error: "Unauthorized: Missing token." }),
          { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
      }

      const callerToken = authHeader.replace("Bearer ", "");
      const { data: { user }, error: authError } = await supabase.auth.getUser(callerToken);
      if (authError || !user) {
        return new Response(
          JSON.stringify({ error: "Unauthorized: Invalid token." }),
          { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
      }

      title = reqBody.title;
      bodyText = reqBody.body;
      const rawData = reqBody.data || {};
      notificationData = Object.fromEntries(
        Object.entries(rawData).map(([k, v]) => [k, String(v)])
      );

      if (reqBody.to_role) {
        // Server-Side Fanout: Query all tokens matching the role
        const { data: profiles, error } = await supabase
          .from("profiles")
          .select("fcm_token")
          .eq("role", reqBody.to_role)
          .not("fcm_token", "is", null);

        if (error) {
          console.error("Profile lookup failed for role:", error.message);
          throw error;
        }
        targets = profiles || [];
        console.log(`[Direct Call] Broadcasting to role ${reqBody.to_role}. Found ${targets.length} targets.`);
      } else {
        // Single user target logic
        const { data: profile, error } = await supabase
          .from("profiles")
          .select("fcm_token")
          .eq("id", reqBody.to_user_id)
          .maybeSingle();

        if (error) {
          console.error("Profile lookup failed for user:", error.message);
          throw error;
        }
        if (profile?.fcm_token) {
          targets.push({ fcm_token: profile.fcm_token });
        }
      }
    }
```

#### [MODIFY] [notification_service.dart](file:///d:/Asansor/lib/core/services/notification_service.dart)

`notifyAllAdmins` metodu client-side loop yapısını bırakıp Edge function'a doğrudan `to_role: 'admin'` gönderecek.

```dart
  Future<void> notifyAllAdmins({
    required SupabaseClient client,
    required String title,
    required String body,
    Map<String, String> data = const {},
  }) async {
    try {
      await client.functions.invoke(
        'send-notification',
        body: {
          'to_role': 'admin',
          'title': title,
          'body': body,
          'data': data,
        },
      );
      debugPrint('[FCM] Sent server-side fanout notification request for admins ✅');
    } catch (e) {
      debugPrint('[FCM] notifyAllAdmins error: $e');
    }
  }
```

---

### Workstream 4 — Çoklu Android Notification Kanalları

#### [MODIFY] [notification_service.dart](file:///d:/Asansor/lib/core/services/notification_service.dart)

Farklı bildirim türleri için 3 adet kanal tanımlanacak ve başlatılma (initialize) sırasında hepsi işletim sistemine kaydettirilecek.

```dart
// Kanalların tanımlanması
const _faultChannel = AndroidNotificationChannel(
  'asansor_faults',
  'Arıza Bildirimleri',
  description: 'Yeni arıza bildirimleri ve durum güncellemeleri',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

const _taskChannel = AndroidNotificationChannel(
  'asansor_tasks',
  'Görev Bildirimleri',
  description: 'Bakım ve onarım görev atamaları',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

const _generalChannel = AndroidNotificationChannel(
  'asansor_general',
  'Genel Bildirimler',
  description: 'Genel duyurular ve sistem bilgilendirmeleri',
  importance: Importance.default,
  playSound: true,
);
```

`_onForegroundMessage` metodu gelen bildirimin tipine göre uygun Android kanalını kullanacak:
```dart
    final type = message.data['type'] as String?;
    final channelId = switch (type) {
      'new_fault' || 'fault_resolved' => _faultChannel.id,
      'task_assigned' || 'task_completed' => _taskChannel.id,
      _ => _generalChannel.id,
    };
```

---

### Workstream 5 — İzin İstemeden Önce Rationale (Gerekçe) Arayüzü

#### [NEW] [notification_rationale_sheet.dart](file:///d:/Asansor/lib/core/widgets/notification_rationale_sheet.dart)

Modern, şık, cam efekti (glassmorphism/blur) ve yumuşak geçişleri olan, HSL renk paletine duyarlı premium bir Bottom Sheet tasarımı oluşturulacak.

**Tasarım Özellikleri:**
- Üst kısımda hafif parlayan ve yavaşça yukarı aşağı salınan (micro-animation) `Icons.notifications_active_outlined` ikonu.
- "Neden bildirim iznine ihtiyacımız var?" başlığı ve faydaları açıklayan ikonlu kartlar.
- İki adet interaktif buton: "Bildirimleri Aç" (Primary, renk geçişli) ve "Daha Sonra" (Plain / Text button).

```dart
// Özet Widget Yapısı
class NotificationRationaleBottomSheet extends StatelessWidget {
  const NotificationRationaleBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    // Premium UI design with Glassmorphism blur, subtle animations and card layout.
    // Clicking "Aç" returns Navigator.pop(context, true);
    // Clicking "Daha Sonra" returns Navigator.pop(context, false);
  }
}
```

#### [MODIFY] [notification_service.dart](file:///d:/Asansor/lib/core/services/notification_service.dart)

- `initialize` metodu içerisinden `_messaging.requestPermission()` çağrısı kaldırılacak. Başlangıçta sadece kanal kurulumları ve listener'lar başlatılacak.
- Yeni yardımcı metotlar eklenecek:

```dart
  /// İznin ilk kez mi istendiğini kontrol eder.
  Future<bool> shouldShowRationale() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.notDetermined;
  }

  /// Gerçek işletim sistemi izin penceresini tetikler.
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }
```

#### [MODIFY] [home_view.dart](file:///d:/Asansor/lib/features/elevator/views/home_view.dart) & [customer_dashboard_view.dart](file:///d:/Asansor/lib/features/customer/views/customer_dashboard_view.dart)

Kullanıcı giriş yaptıktan sonra ilk kez landing sayfasına geldiğinde bu akış işletilecek:

```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotificationPermissions();
    });
  }

  Future<void> _checkNotificationPermissions() async {
    final service = NotificationService.instance;
    final shouldShow = await service.shouldShowRationale();
    if (shouldShow) {
      if (!mounted) return;
      final allowed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const NotificationRationaleBottomSheet(),
      );

      if (allowed == true) {
        final granted = await service.requestPermission();
        if (granted) {
          await service.saveTokenToSupabase(Supabase.instance.client);
        }
      }
    } else {
      // Zaten izin verilmişse token'ı güncel tutmak için veritabanına kaydet
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await service.saveTokenToSupabase(Supabase.instance.client);
      }
    }
  }
```

---

## Doğrulama Planı

### Otomatik Testler

#### [NEW] [notification_service_test.dart](file:///d:/Asansor/test/core/services/notification_service_test.dart)

Aşağıdaki durumları kontrol eden unit testler yazılacak:
1. `NotificationPayload.fromJson` metodunun doğru şekilde `TaskAssignedPayload`, `TaskCompletedPayload`, `ElevatorDetailPayload`, `FaultDetailPayload` objelerini parse ettiği.
2. `determineDestination` fonksiyonunun kullanıcı rollerine (technician, admin) göre doğru rotaları döndürdüğü.
   - Örn: `TaskAssigned` + `UserRole.technician` -> `/`
   - Örn: `TaskAssigned` + `UserRole.admin` -> `/admin/calendar`
   - Örn: `ElevatorDetail` + herhangi bir rol -> `/elevator/{id}`

```bash
# Testleri çalıştırmak için:
flutter test test/core/services/notification_service_test.dart
```

### Manuel Doğrulama Adımları

1. **Yarış Durumu Kontrolü:**
   - Uygulama tamamen kapalıyken (Terminated State) bir bildirim gönderilir.
   - Bildirim tıklandığında uygulama açılır.
   - Yükleme ekranı (`/loading`) bittikten sonra kullanıcının hedeflenen sayfaya (Örn: asansör detayı `/elevator/123`) ulaştığı teyit edilir.
2. **Rol Bazlı Yönlendirme Kontrolü:**
   - Teknisyen hesabı açıkken `task_assigned` bildirimi tıklanır -> `/` (Ana Sayfa) açıldığı görülür.
   - Yönetici (admin) hesabı açıkken `task_assigned` bildirimi tıklanır -> `/admin/calendar` açıldığı görülür.
3. **Rationale Arayüz Kontrolü:**
   - Uygulama izinleri temizlenip sıfırdan kurulur.
   - Giriş yapıldıktan sonra os izin ekranı yerine önce hazırlanan Rationale Bottom Sheet ekranının açıldığı görülür.
   - "Daha Sonra" denildiğinde izin istenmediği, "Bildirimleri Aç" denildiğinde ise OS izin diyalogunun açıldığı teyit edilir.
4. **Sunucu Tarafı Fanout Kontrolü:**
   - Teknisyen bakım kaydettiğinde giden admin bildirim isteği incelenir. İstemcinin tüm adminleri çekmek için SQL sorgusu atmadığı ve tek bir Edge Function çağrısı ile işlemi sunucuya devrettiği (network tabından veya loglardan) doğrulanır.
5. **Android Kanal Kontrolü:**
   - Android cihaz ayarlarından uygulamanın bildirim ayarları açılır.
   - "Arıza Bildirimleri", "Görev Bildirimleri" ve "Genel Bildirimler" kanallarının ayrı ayrı listelendiği doğrulanır.

---

## Kabul Kriterleri

- [ ] Soğuk başlangıçta (terminated state) bildirim tıklanınca yönlendirme hedefine başarıyla gidiliyor (yükleme ekranında kaybolmuyor).
- [ ] Bildirim payload'ları `NotificationPayload` sealed sınıfı üzerinden tip güvenli yönetiliyor.
- [ ] Yönlendirmeler kullanıcı rollerine göre farklılaşıyor (teknisyen ana sayfaya, admin takvime).
- [ ] İstemci tarafındaki `notifyAllAdmins` veritabanı sorgusu ve toplu HTTP döngüsü kaldırıldı, Edge function `to_role` parametresi ile sunucuda gerçekleştiriliyor.
- [ ] Android tarafında "Arıza Bildirimleri", "Görev Bildirimleri" ve "Genel Bildirimler" kanalları sisteme tanımlandı ve kullanılıyor.
- [ ] Bildirim izni istemeden önce kullanıcıya gerekçe arayüzü sunuluyor, agresif izin isteme davranışı engellendi.
- [ ] `notification_service_test.dart` içindeki tüm testler başarıyla geçiyor.
