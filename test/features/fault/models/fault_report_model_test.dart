import 'package:flutter_test/flutter_test.dart';
import 'package:asansor/features/fault/models/fault_report_model.dart';
import '../../../helpers/test_factories.dart';

void main() {
  group('FaultReportModel Tests', () {
    test('fromJson parses complete data correctly', () {
      final reportedAt = DateTime.utc(2026, 1, 15);
      final resolvedAt = DateTime.utc(2026, 1, 16);

      final json = {
        'id': 'f1',
        'elevator_id': 'e1',
        'description': 'Doors not closing',
        'photo_url': 'https://example.com/photo.jpg',
        'fault_type': 'doors',
        'priority': 'high',
        'is_resolved': true,
        'reported_at': reportedAt.toIso8601String(),
        'resolved_at': resolvedAt.toIso8601String(),
        'resolution_notes': 'Fixed sensor',
      };

      final model = FaultReportModel.fromJson(json);

      expect(model.id, 'f1');
      expect(model.elevatorId, 'e1');
      expect(model.description, 'Doors not closing');
      expect(model.photoUrl, 'https://example.com/photo.jpg');
      expect(model.faultType, 'doors');
      expect(model.priority, 'high');
      expect(model.isResolved, isTrue);
      expect(model.reportedAt, reportedAt);
      expect(model.resolvedAt, resolvedAt);
      expect(model.resolutionNotes, 'Fixed sensor');
      expect(model.isOfflineQueued, isFalse); // Default
    });

    test('throws ArgumentError if reported_at is missing', () {
      final json = {
        'id': 'f2',
        // 'reported_at' is missing
      };

      expect(() => FaultReportModel.fromJson(json), throwsArgumentError);
    });

    test('fromJson handles nulls with defaults', () {
      final json = {
        'id': 'f2',
        'elevator_id': 'e2',
        'description': 'Stuck',
        'reported_at': DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
      };

      final model = FaultReportModel.fromJson(json);

      expect(model.id, 'f2');
      expect(model.elevatorId, 'e2');
      expect(model.description, 'Stuck');
      expect(model.photoUrl, isNull);
      expect(model.faultType, isNull);
      expect(model.priority, isNull);
      expect(model.isResolved, isFalse); // Default when null
      expect(
        model.reportedAt,
        DateTime.fromMillisecondsSinceEpoch(0),
      ); // Default when null
      expect(model.resolvedAt, isNull);
      expect(model.resolutionNotes, isNull);
    });

    test('toJson conditionally includes faultType and priority', () {
      final model = TestFactories.createFaultReport(
        faultType: 'motor',
        priority: 'emergency',
      );

      final json = model.toJson();

      expect(json['fault_type'], 'motor');
      expect(json['priority'], 'emergency');
    });

    test('toJson omits faultType and priority when null', () {
      final model = TestFactories.createFaultReport(
        faultType: null,
        priority: null,
      );

      final json = model.toJson();

      expect(json.containsKey('fault_type'), isFalse);
      expect(json.containsKey('priority'), isFalse);
    });

    test('toJson includes null resolvedAt correctly', () {
      final model = TestFactories.createFaultReport(resolvedAt: null);

      final json = model.toJson();

      expect(json.containsKey('resolved_at'), isTrue);
      expect(json['resolved_at'], isNull);
    });

    test('copyWith updates fields', () {
      final original = TestFactories.createFaultReport(
        id: 'orig',
        description: 'Original',
        isResolved: false,
      );

      final updated = original.copyWith(
        description: 'Updated',
        isResolved: true,
        isOfflineQueued: true,
      );

      expect(updated.id, 'orig');
      expect(updated.description, 'Updated');
      expect(updated.isResolved, isTrue);
      expect(updated.isOfflineQueued, isTrue);
    });

    test('toString includes key info', () {
      final model = TestFactories.createFaultReport(
        id: 'f123',
        elevatorId: 'e456',
      );

      expect(model.toString(), contains('f123'));
      expect(model.toString(), contains('e456'));
    });
  });
}
