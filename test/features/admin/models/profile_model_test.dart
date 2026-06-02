import 'package:flutter_test/flutter_test.dart';
import 'package:asansor/features/admin/models/profile_model.dart';
import 'package:asansor/core/enums/app_enums.dart';
import '../../../helpers/test_factories.dart';

void main() {
  group('ProfileModel Tests', () {
    test('fromJson parses complete data correctly', () {
      final json = {
        'id': 'p1',
        'email': 'user@test.com',
        'full_name': 'Ali Yılmaz',
        'phone': '5551234567',
        'role': 'admin',
        'elevator_id': 'e1',
      };

      final model = ProfileModel.fromJson(json);

      expect(model.id, 'p1');
      expect(model.email, 'user@test.com');
      expect(model.fullName, 'Ali Yılmaz');
      expect(model.phone, '5551234567');
      expect(model.role, UserRole.admin);
      expect(model.elevatorId, 'e1');
    });

    test('fromJson handles nulls with defaults', () {
      final json = {'id': 'p2'};

      final model = ProfileModel.fromJson(json);

      expect(model.id, 'p2');
      expect(model.email, isNull);
      expect(model.fullName, isNull);
      expect(model.phone, isNull);
      expect(model.role, UserRole.technician); // Default role
      expect(model.elevatorId, isNull);
    });

    test('toJson converts properly', () {
      final model = TestFactories.createProfile(
        id: 'p3',
        email: 'x@x.com',
        fullName: 'Test X',
        phone: '123',
        role: UserRole.customer,
        elevatorId: 'e3',
      );

      final json = model.toJson();

      expect(json['id'], 'p3');
      expect(json['email'], 'x@x.com');
      expect(json['full_name'], 'Test X');
      expect(json['phone'], '123');
      expect(json['role'], 'customer');
      expect(json['elevator_id'], 'e3');
    });

    group('displayName', () {
      test('returns fullName if not empty', () {
        final model = TestFactories.createProfile(fullName: 'Veli');
        expect(model.displayName, 'Veli');
      });

      test('returns email prefix if fullName is empty/null', () {
        final model = TestFactories.createProfile(
          fullName: null,
          email: 'veli.can@test.com',
        );
        expect(model.displayName, 'veli.can');
      });

      test('returns id prefix if both fullName and email are empty/null', () {
        final model = TestFactories.createProfile(
          fullName: null,
          email: null,
          id: '1234567890',
        );
        expect(model.displayName, '12345678');
      });

      test('returns full id if id is short', () {
        final model = TestFactories.createProfile(
          fullName: null,
          email: null,
          id: '123',
        );
        expect(model.displayName, '123');
      });
    });

    group('initials', () {
      test('returns initials for 2+ words', () {
        final model = TestFactories.createProfile(fullName: 'Ahmet Yılmaz');
        expect(model.initials, 'AY');

        final model3 = TestFactories.createProfile(
          fullName: 'Ahmet Can Yılmaz',
        );
        expect(model3.initials, 'AY'); // First and last word initials
      });

      test('returns first 2 chars for single word', () {
        final model = TestFactories.createProfile(fullName: 'Ahmet');
        expect(model.initials, 'AH');
      });

      test('returns 1 char if word is short', () {
        final model = TestFactories.createProfile(fullName: 'A');
        expect(model.initials, 'A');
      });

      test('returns fallback if no name', () {
        final model = TestFactories.createProfile(
          fullName: null,
          email: 'user@test.com',
        );
        expect(model.initials, 'US'); // email prefix first 2 letters
      });
    });

    group('roleTr', () {
      test('translates roles correctly', () {
        expect(
          TestFactories.createProfile(role: UserRole.admin).roleTr,
          'Admin',
        );
        expect(
          TestFactories.createProfile(role: UserRole.technician).roleTr,
          'Teknisyen',
        );
        expect(
          TestFactories.createProfile(role: UserRole.customer).roleTr,
          'Müşteri',
        );
      });
    });

    group('role booleans', () {
      test('isAdmin', () {
        expect(
          TestFactories.createProfile(role: UserRole.admin).isAdmin,
          isTrue,
        );
        expect(
          TestFactories.createProfile(role: UserRole.technician).isAdmin,
          isFalse,
        );
      });

      test('isTechnician', () {
        expect(
          TestFactories.createProfile(role: UserRole.technician).isTechnician,
          isTrue,
        );
        expect(
          TestFactories.createProfile(role: UserRole.customer).isTechnician,
          isFalse,
        );
      });

      test('isCustomer', () {
        expect(
          TestFactories.createProfile(role: UserRole.customer).isCustomer,
          isTrue,
        );
        expect(
          TestFactories.createProfile(role: UserRole.admin).isCustomer,
          isFalse,
        );
      });
    });

    test('copyWith updates fields', () {
      final original = TestFactories.createProfile(
        id: '1',
        role: UserRole.technician,
        elevatorId: 'e1',
      );

      final updated = original.copyWith(role: UserRole.admin);

      expect(updated.id, '1');
      expect(updated.role, UserRole.admin);
      expect(updated.elevatorId, 'e1');

      final cleared = original.copyWith(clearElevatorId: true);
      expect(cleared.elevatorId, isNull);
    });
  });
}
