import 'package:flutter_test/flutter_test.dart';
import 'package:asansor/features/maintenance/models/maintenance_log_model.dart';

void main() {
  group('MaintenanceLogModel — fromJson / toJson', () {
    test('roundtrip with all fields present', () {
      final json = {
        'id': 'log-1',
        'elevator_id': 'elev-1',
        'technician_id': 'tech-1',
        'notes': 'Kapılar kontrol edildi.',
        'is_approved': true,
        'maintenance_date': '2026-01-15T09:00:00.000Z',
        'pdf_url': 'https://example.com/report.pdf',
        'checklist': {'doors': true, 'cables': false},
        'photos': [
          'https://example.com/photo1.jpg',
          'https://example.com/photo2.jpg',
        ],
        'signature_url': 'https://example.com/sig.png',
        'customer_signature_url': 'https://example.com/custsig.png',
        'profiles': {'full_name': 'Ahmet Yılmaz'},
      };

      final model = MaintenanceLogModel.fromJson(json);

      expect(model.id, 'log-1');
      expect(model.elevatorId, 'elev-1');
      expect(model.technicianId, 'tech-1');
      expect(model.notes, 'Kapılar kontrol edildi.');
      expect(model.isApproved, isTrue);
      expect(model.maintenanceDate, DateTime.parse('2026-01-15T09:00:00.000Z'));
      expect(model.pdfUrl, 'https://example.com/report.pdf');
      expect(model.checklist, {'doors': true, 'cables': false});
      expect(model.photos, [
        'https://example.com/photo1.jpg',
        'https://example.com/photo2.jpg',
      ]);
      expect(model.signatureUrl, 'https://example.com/sig.png');
      expect(model.customerSignatureUrl, 'https://example.com/custsig.png');
      expect(model.technicianName, 'Ahmet Yılmaz');
      expect(model.isOfflineQueued, isFalse); // varsayılan

      final out = model.toJson();
      expect(out['id'], 'log-1');
      expect(out['elevator_id'], 'elev-1');
      expect(out['technician_id'], 'tech-1');
      expect(out['notes'], 'Kapılar kontrol edildi.');
      expect(out['is_approved'], true);
      expect(out['maintenance_date'], '2026-01-15T09:00:00.000Z');
      expect(out['pdf_url'], 'https://example.com/report.pdf');
      expect(out['checklist'], {'doors': true, 'cables': false});
      expect(out['photos'], [
        'https://example.com/photo1.jpg',
        'https://example.com/photo2.jpg',
      ]);
      expect(out['signature_url'], 'https://example.com/sig.png');
      expect(out['customer_signature_url'], 'https://example.com/custsig.png');
      // technicianName DB'ye yazılmaz
      expect(out.containsKey('technician_name'), isFalse);
    });

    test('null nullable alanlar varsayılan değerleri alır', () {
      final json = {
        'id': 'log-2',
        'elevator_id': null, // null FK
        'technician_id': null, // null FK
        'maintenance_date': '2026-03-01T00:00:00.000Z',
        // notes, pdf_url, checklist, photos, signature_url, customer_signature_url, profiles: yok
      };

      final model = MaintenanceLogModel.fromJson(json);

      expect(model.elevatorId, ''); // null → boş string
      expect(model.technicianId, ''); // null → boş string
      expect(model.notes, isNull);
      expect(model.isApproved, isFalse); // null → false
      expect(model.pdfUrl, isNull);
      expect(model.technicianName, isNull);
      expect(model.checklist, isNull);
      expect(model.photos, isNull);
      expect(model.signatureUrl, isNull);
      expect(model.customerSignatureUrl, isNull);
    });

    test('throws ArgumentError if maintenance_date is missing', () {
      final json = {
        'id': 'log-3',
        'elevator_id': 'elev-3',
        'technician_id': 'tech-3',
        // 'maintenance_date' is missing
      };

      expect(() => MaintenanceLogModel.fromJson(json), throwsArgumentError);
    });

    test('toJson: isteğe bağlı alanlar null ise eksik olur', () {
      final model = MaintenanceLogModel(
        id: 'log-4',
        elevatorId: 'elev-1',
        technicianId: 'tech-1',
        isApproved: false,
        maintenanceDate: DateTime(2026, 5, 1),
        // photos, signatureUrl, customerSignatureUrl: yok
      );

      final out = model.toJson();
      expect(out.containsKey('photos'), isFalse);
      expect(out.containsKey('signature_url'), isFalse);
      expect(out.containsKey('customer_signature_url'), isFalse);
    });

    test('copyWith sadece belirtilen alanları günceller', () {
      final original = MaintenanceLogModel(
        id: 'log-5',
        elevatorId: 'elev-1',
        technicianId: 'tech-1',
        isApproved: false,
        maintenanceDate: DateTime(2026, 6, 1),
        notes: 'Orijinal not',
      );

      final copy = original.copyWith(
        notes: 'Güncellenmiş not',
        isApproved: true,
      );

      expect(copy.id, 'log-5'); // değişmedi
      expect(copy.elevatorId, 'elev-1'); // değişmedi
      expect(copy.notes, 'Güncellenmiş not'); // güncellendi
      expect(copy.isApproved, isTrue); // güncellendi
    });
  });
}
