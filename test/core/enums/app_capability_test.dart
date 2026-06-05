import 'package:flutter_test/flutter_test.dart';
import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/enums/app_capability.dart';
import 'package:asansor/features/admin/models/profile_model.dart';
import 'package:asansor/features/auth/providers/auth_providers.dart';

void main() {
  group('AppCapability and UserRole Integration Tests', () {
    test('capabilityMatrix should cover all UserRoles', () {
      for (final role in UserRole.values) {
        expect(capabilityMatrix.containsKey(role), isTrue,
            reason: 'Missing capability matrix for role: $role');
      }
    });

    test('Admin should have accessAdminPanel capability', () {
      expect(capabilityMatrix[UserRole.admin]?.contains(AppCapability.accessAdminPanel), isTrue);
    });

    test('Technician should not have accessAdminPanel capability', () {
      expect(capabilityMatrix[UserRole.technician]?.contains(AppCapability.accessAdminPanel), isFalse);
    });

    test('Customer should not have accessAdminPanel capability', () {
      expect(capabilityMatrix[UserRole.customer]?.contains(AppCapability.accessAdminPanel), isFalse);
    });
  });

  group('ProfileModel Capability Check', () {
    test('Admin Profile can perform Admin capabilities', () {
      final profile = ProfileModel(
        id: '1',
        role: UserRole.admin,
        fullName: 'Admin User',
      );

      expect(profile.can(AppCapability.accessAdminPanel), isTrue);
      expect(profile.can(AppCapability.manageUsers), isTrue);
    });

    test('Technician Profile can log maintenance', () {
      final profile = ProfileModel(
        id: '2',
        role: UserRole.technician,
        fullName: 'Technician User',
      );

      expect(profile.can(AppCapability.logMaintenance), isTrue);
      expect(profile.can(AppCapability.manageUsers), isFalse);
    });
  });

  group('AuthStateModel Capability Check', () {
    test('Authorized Admin AuthState can perform Admin capabilities', () {
      final authState = AuthStateModel(
        status: AuthStatus.authorized,
        role: UserRole.admin,
      );

      expect(authState.can(AppCapability.accessAdminPanel), isTrue);
    });

    test('Unauthorized Admin AuthState cannot perform Admin capabilities', () {
      final authState = AuthStateModel(
        status: AuthStatus.unauthenticated,
        role: UserRole.admin,
      );

      expect(authState.can(AppCapability.accessAdminPanel), isFalse);
    });

    test('Null role cannot perform capabilities', () {
      final authState = AuthStateModel(
        status: AuthStatus.authorized,
        role: null,
      );

      expect(authState.can(AppCapability.accessAdminPanel), isFalse);
    });
  });
}
