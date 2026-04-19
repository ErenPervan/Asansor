import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_model.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'profiles';

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Returns the profile for a single [userId], or `null` if none exists yet.
  Future<ProfileModel?> getProfile(String userId) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return ProfileModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to load profile ($userId): ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error loading profile: $e');
    }
  }

  /// Returns every profile row, ordered by role then name.
  Future<List<ProfileModel>> getAllProfiles() async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .order('role', ascending: true)
          .order('full_name', ascending: true);

      return (response as List)
          .map((json) => ProfileModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load profiles: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error loading profiles: $e');
    }
  }

  /// Returns profiles filtered by [role] (`'admin'` | `'technician'` | `'customer'`).
  Future<List<ProfileModel>> getProfilesByRole(String role) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('role', role)
          .order('full_name', ascending: true);

      return (response as List)
          .map((json) => ProfileModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load $role profiles: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error loading $role profiles: $e');
    }
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Changes the [role] of [userId] and returns the updated profile.
  ///
  /// Requires the caller to be an admin (enforced by Supabase RLS).
  /// Accepted values: `'admin'` | `'technician'` | `'customer'`
  Future<ProfileModel> updateRole(String userId, String newRole) async {
    assert(
      const ['admin', 'technician', 'customer'].contains(newRole),
      'updateRole: "$newRole" is not a valid role.',
    );
    try {
      final response = await _client
          .from(_table)
          .update({'role': newRole})
          .eq('id', userId)
          .select()
          .single();

      return ProfileModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update role for $userId: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error updating role: $e');
    }
  }

  /// Updates (or clears) the elevator linked to a customer profile.
  ///
  /// Pass `null` for [elevatorId] to unlink the elevator.
  Future<ProfileModel> updateCustomerElevator(
    String userId,
    String? elevatorId,
  ) async {
    try {
      final response = await _client
          .from(_table)
          .update({'elevator_id': elevatorId})
          .eq('id', userId)
          .select()
          .single();

      return ProfileModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception(
          'Failed to update elevator for customer $userId: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error updating customer elevator: $e');
    }
  }

  /// Updates name and/or phone of [userId]'s profile.
  Future<ProfileModel> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
  }) async {
    final payload = <String, dynamic>{};
    if (fullName != null) payload['full_name'] = fullName;
    if (phone != null) payload['phone'] = phone;

    try {
      final response = await _client
          .from(_table)
          .update(payload)
          .eq('id', userId)
          .select()
          .single();

      return ProfileModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update profile for $userId: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error updating profile: $e');
    }
  }
}
