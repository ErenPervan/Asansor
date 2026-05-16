import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/checklist_item_model.dart';

class ChecklistRepository {
  ChecklistRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'checklist_items';

  /// Fetches all active checklist items from the database.
  Future<List<ChecklistItemModel>> getActiveItems() async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: true);

      return (response as List<dynamic>)
          .map((json) => ChecklistItemModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load checklist items: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }
}
