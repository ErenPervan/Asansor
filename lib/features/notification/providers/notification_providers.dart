import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import '../../../core/models/paginated_state.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(Supabase.instance.client);
});

final notificationListProvider =
    AsyncNotifierProvider<NotificationController, PaginatedState<NotificationModel>>(
        NotificationController.new);

class NotificationController extends AsyncNotifier<PaginatedState<NotificationModel>> {
  static const _pageSize = 20;

  @override
  Future<PaginatedState<NotificationModel>> build() async {
    final items = await ref.watch(notificationRepositoryProvider).fetchNotifications(
      from: 0,
      to: _pageSize - 1,
    );
    return PaginatedState(
      items: items,
      hasMore: items.length == _pageSize,
    );
  }

  Future<void> loadMore() async {
    final currentState = state.value;
    if (currentState == null || !currentState.hasMore || currentState.isLoadingMore) {
      return;
    }

    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    final nextFrom = currentState.items.length;
    final nextTo = nextFrom + _pageSize - 1;

    try {
      final newItems = await ref.read(notificationRepositoryProvider).fetchNotifications(
        from: nextFrom,
        to: nextTo,
      );

      state = AsyncData(currentState.copyWith(
        items: [...currentState.items, ...newItems],
        hasMore: newItems.length == _pageSize,
        isLoadingMore: false,
      ));
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<void> markAsRead(String id) async {
    final previousState = state.value;
    if (previousState == null) return;

    // Optimistic Update
    state = AsyncData(previousState.copyWith(
      items: previousState.items.map((n) {
        if (n.id == id) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList(),
    ));

    try {
      await ref.read(notificationRepositoryProvider).markAsRead(id);
    } catch (e) {
      // Revert on error
      state = AsyncData(previousState);
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final items = await ref.read(notificationRepositoryProvider).fetchNotifications(
            from: 0,
            to: _pageSize - 1,
          );
      return PaginatedState(
        items: items,
        hasMore: items.length == _pageSize,
      );
    });
  }
}

/// Provider for unread notification count
final unreadNotificationCountProvider = Provider<int>((ref) {
  final paginatedState = ref.watch(notificationListProvider).value;
  if (paginatedState == null) return 0;
  return paginatedState.items.where((n) => !n.isRead).length;
});
