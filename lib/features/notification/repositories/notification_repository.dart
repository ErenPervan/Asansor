import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final SupabaseClient _client;

  NotificationRepository(this._client);

  /// Fetches the current user's notifications, ordered from newest to oldest.
  Future<List<NotificationModel>> fetchNotifications({int from = 0, int to = 19}) async {
    final response = await _client
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .range(from, to);
    
    return (response as List).map((json) => NotificationModel.fromJson(json)).toList();
  }

  /// Marks a specific notification as read.
  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }
}
