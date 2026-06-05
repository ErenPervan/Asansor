import '../enums/app_capability.dart';
import '../../features/auth/providers/auth_providers.dart';

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
String determineDestination(
  NotificationPayload payload,
  AuthStateModel? authState,
) {
  final canViewAdminCalendar =
      authState?.can(AppCapability.viewAdminCalendar) ?? false;
  return switch (payload) {
    TaskAssignedPayload() =>
      canViewAdminCalendar
          ? '/admin/calendar' // Yönetici için takvim ekranı
          : '/', // Teknisyen için ana sayfa (görev listesi)
    TaskCompletedPayload(:final route) =>
      canViewAdminCalendar
          ? (route.isNotEmpty ? route : '/admin/master-calendar')
          : '/',
    ElevatorDetailPayload(:final elevatorId) => '/elevator/$elevatorId',
    FaultDetailPayload(:final faultId) => '/fault/$faultId',
    ExplicitRoutePayload(:final route) => route,
    FallbackPayload() => '/',
  };
}
