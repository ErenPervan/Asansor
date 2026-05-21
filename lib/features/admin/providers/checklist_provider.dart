import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/connectivity_providers.dart';
import '../models/checklist_item_model.dart';

class ChecklistNotifier extends AutoDisposeAsyncNotifier<List<ChecklistItemModel>> {
  @override
  Future<List<ChecklistItemModel>> build() async {
    return _fetchItems();
  }

  Future<List<ChecklistItemModel>> _fetchItems() async {
    final isOnline = ref.read(isOnlineProvider);
    final cache = ref.read(readCacheServiceProvider);

    if (!isOnline) {
      return cache.loadChecklistItems(ChecklistItemModel.fromJson).cast<ChecklistItemModel>();
    }

    try {
      final response = await Supabase.instance.client
          .from('checklist_items')
          .select()
          .order('label', ascending: true);
          
      final items = response.map((e) => ChecklistItemModel.fromJson(e)).toList();
      cache.saveChecklistItems(items);
      return items;
    } catch (e) {
      final cached = cache.loadChecklistItems(ChecklistItemModel.fromJson).cast<ChecklistItemModel>();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<void> addItem(String label, String description) async {
    state = const AsyncLoading();
    
    state = await AsyncValue.guard(() async {
      await Supabase.instance.client.from('checklist_items').insert({
        'label': label,
        'description': description,
        'is_active': true,
      });
      return _fetchItems();
    });
  }

  Future<void> updateItem(String id, String label, String description) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await Supabase.instance.client.from('checklist_items').update({
        'label': label,
        'description': description,
      }).eq('id', id);
      return _fetchItems();
    });
  }

  Future<void> toggleActiveStatus(String id, bool isActive) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await Supabase.instance.client.from('checklist_items').update({
        'is_active': isActive,
      }).eq('id', id);
      return _fetchItems();
    });
  }

  Future<void> deleteItem(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await Supabase.instance.client
          .from('checklist_items')
          .delete()
          .eq('id', id);
      return _fetchItems();
    });
  }
}

final checklistProvider =
    AsyncNotifierProvider.autoDispose<ChecklistNotifier, List<ChecklistItemModel>>(
  ChecklistNotifier.new,
);
