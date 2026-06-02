import 'package:flutter_test/flutter_test.dart';
import 'package:asansor/features/admin/models/checklist_item_model.dart';

void main() {
  group('ChecklistItemModel — fromJson / toJson', () {
    test('roundtrip with all fields present', () {
      final json = {
        'id': 'item-1',
        'label': 'Kapı Kontrolü',
        'description': 'Kapıların düzgün kapandığını kontrol edin.',
        'is_active': true,
      };

      final model = ChecklistItemModel.fromJson(json);

      expect(model.id, 'item-1');
      expect(model.label, 'Kapı Kontrolü');
      expect(model.description, 'Kapıların düzgün kapandığını kontrol edin.');
      expect(model.isActive, isTrue);

      final out = model.toJson();
      expect(out['id'], 'item-1');
      expect(out['label'], 'Kapı Kontrolü');
      expect(out['description'], 'Kapıların düzgün kapandığını kontrol edin.');
      expect(out['is_active'], true);
    });

    test('description null ise boş string döner', () {
      final json = {
        'id': 'item-2',
        'label': 'Kablo Kontrolü',
        'description': null,
        'is_active': true,
      };

      final model = ChecklistItemModel.fromJson(json);
      expect(model.description, '');
    });

    test('is_active null ise varsayılan olarak true döner', () {
      final json = {
        'id': 'item-3',
        'label': 'Yağlama',
        'description': 'Hareketli parçaları yağlayın.',
        // is_active: yok
      };

      final model = ChecklistItemModel.fromJson(json);
      expect(model.isActive, isTrue);
    });

    test('is_active false olarak okunabilir', () {
      final json = {
        'id': 'item-4',
        'label': 'Eski Kontrol',
        'description': 'Devre dışı bırakıldı.',
        'is_active': false,
      };

      final model = ChecklistItemModel.fromJson(json);
      expect(model.isActive, isFalse);
    });

    test('copyWith sadece belirtilen alanları günceller', () {
      const original = ChecklistItemModel(
        id: 'item-5',
        label: 'Orijinal',
        description: 'Açıklama',
        isActive: true,
      );

      final copy = original.copyWith(label: 'Güncellenmiş', isActive: false);

      expect(copy.id, 'item-5'); // değişmedi
      expect(copy.description, 'Açıklama'); // değişmedi
      expect(copy.label, 'Güncellenmiş'); // güncellendi
      expect(copy.isActive, isFalse); // güncellendi
    });

    test('toJson → fromJson tam roundtrip', () {
      const model = ChecklistItemModel(
        id: 'item-6',
        label: 'Emniyet Kontrolü',
        description: 'Emniyet frenlerini test edin.',
        isActive: true,
      );

      final restored = ChecklistItemModel.fromJson(model.toJson());
      expect(restored.id, model.id);
      expect(restored.label, model.label);
      expect(restored.description, model.description);
      expect(restored.isActive, model.isActive);
    });
  });
}
