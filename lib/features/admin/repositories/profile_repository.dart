import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/exceptions/app_exception.dart';
import '../models/profile_model.dart';

abstract interface class IProfileRepository {
  Future<ProfileModel?> getProfile(String userId);
  Future<List<ProfileModel>> getAllProfiles();
  Future<List<ProfileModel>> getProfilesByRole(String role);
  Future<ProfileModel> updateRole(String userId, String newRole);
  Future<ProfileModel> updateCustomerElevator(
    String userId,
    String? elevatorId,
  );
  Future<ProfileModel> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
  });
}

class ProfileRepository implements IProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'profiles';

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Returns the profile for a single [userId], or `null` if none exists yet.
  @override
  Future<ProfileModel?> getProfile(String userId) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return ProfileModel.fromJson(response);
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getProfile($userId)');
    } catch (e) {
      throw mapUnknownException(e, 'getProfile($userId)');
    }
  }

  /// Returns every profile row, ordered by role then name.
  @override
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
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getAllProfiles');
    } catch (e) {
      throw mapUnknownException(e, 'getAllProfiles');
    }
  }

  /// Returns profiles filtered by [role] (`'admin'` | `'technician'` | `'customer'`).
  @override
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
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'getProfilesByRole($role)');
    } catch (e) {
      throw mapUnknownException(e, 'getProfilesByRole($role)');
    }
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Changes the [role] of [userId] and returns the updated profile.
  ///
  /// Requires the caller to be an admin (enforced by Supabase RLS).
  /// Accepted values: `'admin'` | `'technician'` | `'customer'`
  @override
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
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'updateRole($userId)');
    } catch (e) {
      throw mapUnknownException(e, 'updateRole($userId)');
    }
  }

  /// Updates (or clears) the elevator linked to a customer profile.
  ///
  /// Pass `null` for [elevatorId] to unlink the elevator.
  @override
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
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'updateCustomerElevator($userId)');
    } catch (e) {
      throw mapUnknownException(e, 'updateCustomerElevator($userId)');
    }
  }

  /// Updates name and/or phone of [userId]'s profile.
  @override
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
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw mapPostgrestException(e, 'updateProfile($userId)');
    } catch (e) {
      throw mapUnknownException(e, 'updateProfile($userId)');
    }
  }
}
