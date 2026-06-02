import 'package:flutter_test/flutter_test.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/features/maintenance/models/maintenance_log_model.dart';

void main() {
  group('InspectionStatus Tests', () {
    test('fromDb handles valid and invalid values', () {
      expect(InspectionStatusX.fromDb('green'), InspectionStatus.green);
      expect(InspectionStatusX.fromDb('red'), InspectionStatus.red);
      expect(InspectionStatusX.fromDb('unknown_value'), InspectionStatus.none);
      expect(InspectionStatusX.fromDb(null), InspectionStatus.none);
    });

    test('dbValue returns correct string', () {
      expect(InspectionStatus.red.dbValue, 'red');
      expect(InspectionStatus.blue.dbValue, 'blue');
      expect(InspectionStatus.none.dbValue, 'none');
    });
  });

  group('ElevatorModel Tests', () {
    test('fromJson handles complete data correctly', () {
      final json = {
        'id': 'e1',
        'building_name': 'Apt A',
        'address': '123 Main St',
        'status': 'active',
        'latitude': 41.0082,
        'longitude': 28.9784,
        'maintenance_day': 15,
        'model': 'Otis Gen2',
        'capacity': 630,
        'last_inspection_date': '2026-01-01T10:00:00.000Z',
        'next_inspection_date': '2027-01-01T10:00:00.000Z',
        'inspection_status': 'green',
        'version': 2,
      };

      final model = ElevatorModel.fromJson(json);

      expect(model.id, 'e1');
      expect(model.buildingName, 'Apt A');
      expect(model.address, '123 Main St');
      expect(model.status, ElevatorStatus.active);
      expect(model.latitude, 41.0082);
      expect(model.longitude, 28.9784);
      expect(model.maintenanceDay, 15);
      expect(model.model, 'Otis Gen2');
      expect(model.capacity, 630);
      expect(
        model.lastInspectionDate,
        DateTime.parse('2026-01-01T10:00:00.000Z'),
      );
      expect(
        model.nextInspectionDate,
        DateTime.parse('2027-01-01T10:00:00.000Z'),
      );
      expect(model.inspectionStatus, InspectionStatus.green);
      expect(model.version, 2);
      expect(model.hasMappableLocation, isTrue);
      expect(model.hasMaintenanceContract, isTrue);
    });

    test(
      'fromJson handles null/omitted model, capacity and other nullable fields',
      () {
        final json = {'id': 'e2', 'status': 'inactive'};

        final model = ElevatorModel.fromJson(json);

        expect(model.id, 'e2');
        expect(model.buildingName, ''); // Empty string fallback
        expect(model.address, isNull);
        expect(model.status, ElevatorStatus.inactive);
        expect(model.latitude, isNull);
        expect(model.longitude, isNull);
        expect(model.maintenanceDay, isNull);
        expect(model.model, isNull);
        expect(model.capacity, isNull);
        expect(model.lastInspectionDate, isNull);
        expect(model.nextInspectionDate, isNull);
        expect(model.inspectionStatus, InspectionStatus.none);
        expect(model.version, 1); // Default value
        expect(model.hasMappableLocation, isFalse);
        expect(model.hasMaintenanceContract, isFalse);
      },
    );

    test(
      'toJson serializes model correctly (omits nulls except version/status)',
      () {
        const model = ElevatorModel(
          id: 'e3',
          buildingName: 'Apt B',
          status: ElevatorStatus.underMaintenance,
          version: 3,
        );

        final json = model.toJson();

        expect(json['id'], 'e3');
        expect(json['building_name'], 'Apt B');
        expect(json['status'], 'under_maintenance');
        expect(json['version'], 3);
        expect(json['address'], isNull);
        expect(json.containsKey('latitude'), isFalse);
        expect(json.containsKey('longitude'), isFalse);
        expect(json.containsKey('maintenance_day'), isFalse);
        expect(json.containsKey('model'), isFalse);
        expect(json.containsKey('capacity'), isFalse);
        expect(json['last_inspection_date'], isNull);
        expect(json['next_inspection_date'], isNull);
        expect(json['inspection_status'], 'none');
      },
    );

    test(
      'toJson includes model, capacity, and inspection dates when not null',
      () {
        final lastIns = DateTime(2026, 1, 1);
        final nextIns = DateTime(2027, 1, 1);
        final model = ElevatorModel(
          id: 'e4',
          buildingName: 'Apt C',
          status: ElevatorStatus.faulty,
          model: 'Schindler 3300',
          capacity: 800,
          lastInspectionDate: lastIns,
          nextInspectionDate: nextIns,
          inspectionStatus: InspectionStatus.red,
          version: 1,
        );

        final json = model.toJson();

        expect(json['model'], 'Schindler 3300');
        expect(json['capacity'], 800);
        expect(json['last_inspection_date'], lastIns.toIso8601String());
        expect(json['next_inspection_date'], nextIns.toIso8601String());
        expect(json['inspection_status'], 'red');
      },
    );

    test('copyWith duplicates values and overrides specified fields', () {
      const original = ElevatorModel(
        id: 'e5',
        buildingName: 'Apt D',
        status: ElevatorStatus.active,
        model: 'Kone MonoSpace',
        capacity: 450,
        inspectionStatus: InspectionStatus.blue,
        version: 1,
      );

      final updated = original.copyWith(
        status: ElevatorStatus.faulty,
        capacity: 630,
        model: 'Kone MonoSpace DX',
        inspectionStatus: InspectionStatus.red,
      );

      expect(updated.id, 'e5');
      expect(updated.buildingName, 'Apt D');
      expect(updated.status, ElevatorStatus.faulty);
      expect(updated.model, 'Kone MonoSpace DX');
      expect(updated.capacity, 630);
      expect(updated.inspectionStatus, InspectionStatus.red);
      expect(updated.version, 1);
    });

    test('toString returns proper representation', () {
      const model = ElevatorModel(
        id: 'e6',
        buildingName: 'Apt E',
        status: ElevatorStatus.active,
        model: 'Otis',
        capacity: 1000,
        inspectionStatus: InspectionStatus.green,
        version: 4,
      );

      expect(model.toString(), contains('model: Otis, capacity: 1000'));
      expect(model.toString(), contains('inspection: green, version: 4'));
    });
  });

  group('MaintenanceLogModel Tests', () {
    test('fromJson handles complete data with profiles join correctly', () {
      final json = {
        'id': 'log1',
        'elevator_id': 'e1',
        'technician_id': 'tech1',
        'notes': 'All checks passed',
        'is_approved': true,
        'maintenance_date': '2026-05-17T12:00:00.000Z',
        'pdf_url': 'https://supabase.com/reports/log1.pdf',
        'profiles': {'full_name': 'John Doe'},
      };

      final model = MaintenanceLogModel.fromJson(json);

      expect(model.id, 'log1');
      expect(model.elevatorId, 'e1');
      expect(model.technicianId, 'tech1');
      expect(model.notes, 'All checks passed');
      expect(model.isApproved, isTrue);
      expect(model.maintenanceDate, DateTime.parse('2026-05-17T12:00:00.000Z'));
      expect(model.pdfUrl, 'https://supabase.com/reports/log1.pdf');
      expect(model.technicianName, 'John Doe');
      expect(model.isOfflineQueued, isFalse);
    });

    test('fromJson handles null values and missing profiles nested map', () {
      final json = {'id': 'log2'};

      final model = MaintenanceLogModel.fromJson(json);

      expect(model.id, 'log2');
      expect(model.elevatorId, ''); // Default fallback
      expect(model.technicianId, ''); // Default fallback
      expect(model.notes, isNull);
      expect(model.isApproved, isFalse); // Default fallback
      expect(
        model.maintenanceDate,
        DateTime.fromMillisecondsSinceEpoch(0),
      ); // Sentinel value fallback
      expect(model.pdfUrl, isNull);
      expect(model.technicianName, isNull);
      expect(model.isOfflineQueued, isFalse);
    });

    test('toJson serializes correctly (excludes technicianName)', () {
      final date = DateTime(2026, 5, 17, 12, 0);
      final model = MaintenanceLogModel(
        id: 'log3',
        elevatorId: 'e2',
        technicianId: 'tech2',
        notes: 'Needs cable replacement',
        isApproved: false,
        maintenanceDate: date,
        pdfUrl: null,
        technicianName: 'Jane Smith',
      );

      final json = model.toJson();

      expect(json['id'], 'log3');
      expect(json['elevator_id'], 'e2');
      expect(json['technician_id'], 'tech2');
      expect(json['notes'], 'Needs cable replacement');
      expect(json['is_approved'], isFalse);
      expect(json['maintenance_date'], date.toIso8601String());
      expect(json['pdf_url'], isNull);
      expect(json.containsKey('technicianName'), isFalse);
      expect(json.containsKey('technician_name'), isFalse);
    });

    test('copyWith duplicates values and overrides specified fields', () {
      final date = DateTime(2026, 5, 17, 12, 0);
      final original = MaintenanceLogModel(
        id: 'log4',
        elevatorId: 'e2',
        technicianId: 'tech2',
        isApproved: false,
        maintenanceDate: date,
        technicianName: 'Jane Smith',
      );

      final updated = original.copyWith(
        notes: 'Cable replaced',
        isApproved: true,
        technicianName: 'Jane Watson',
        isOfflineQueued: true,
      );

      expect(updated.id, 'log4');
      expect(updated.elevatorId, 'e2');
      expect(updated.technicianId, 'tech2');
      expect(updated.notes, 'Cable replaced');
      expect(updated.isApproved, isTrue);
      expect(updated.maintenanceDate, date);
      expect(updated.technicianName, 'Jane Watson');
      expect(updated.isOfflineQueued, isTrue);
    });
  });
}
