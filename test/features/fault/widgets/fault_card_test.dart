import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/elevator/widgets/home/home_active_faults.dart';
import 'package:asansor/features/fault/models/fault_report_model.dart';

// Minimal MaterialApp wrapper — GoRouter gerektirmeyen bağımsız test.
Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

FaultReportModel _fault({
  String id = 'f1',
  String description = 'Arıza açıklaması',
  DateTime? reportedAt,
}) {
  return FaultReportModel(
    id: id,
    elevatorId: 'elev-1',
    description: description,
    isResolved: false,
    reportedAt: reportedAt ?? DateTime.now().subtract(const Duration(hours: 2)),
  );
}

void main() {
  group('FaultCard Widget', () {
    testWidgets('bina adını ve açıklamayı gösterir', (tester) async {
      final fault = _fault(description: 'Kapı motoru arızası');

      await tester.pumpWidget(
        _wrap(
          FaultCard(
            fault: fault,
            buildingName: 'Yıldız Plaza',
            address: 'Kadıköy, İstanbul',
            cardWidth: 320,
          ),
        ),
      );

      expect(find.text('Yıldız Plaza'), findsOneWidget);
      expect(find.text('Kapı motoru arızası'), findsOneWidget);
      expect(find.text('Kadıköy, İstanbul'), findsOneWidget);
    });

    testWidgets('başlık bandında ACİL ARIZA etiketi görünür', (tester) async {
      final fault = _fault();

      await tester.pumpWidget(
        _wrap(
          FaultCard(
            fault: fault,
            buildingName: 'Test Bina',
            address: '',
            cardWidth: 300,
          ),
        ),
      );

      expect(find.text('ACİL ARIZA'), findsOneWidget);
    });

    testWidgets('boş açıklama olunca fallback metin gösterilir', (
      tester,
    ) async {
      final fault = _fault(description: '');

      await tester.pumpWidget(
        _wrap(
          FaultCard(
            fault: fault,
            buildingName: 'Test Bina',
            address: '',
            cardWidth: 300,
          ),
        ),
      );

      expect(find.text('Arıza bildirimi alındı.'), findsOneWidget);
    });

    testWidgets('onTap çağrıldığında callback tetiklenir', (tester) async {
      final fault = _fault();
      var tapped = false;

      await tester.pumpWidget(
        _wrap(
          FaultCard(
            fault: fault,
            buildingName: 'Test Bina',
            address: 'Adres',
            cardWidth: 300,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector).first);
      expect(tapped, isTrue);
    });
  });

  group('ActiveFaultsSection Widget', () {
    testWidgets('loading durumunda LoadingState görünür', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ActiveFaultsSection(
            activeFaults: AsyncLoading(),
            elevators: null,
          ),
        ),
      );

      // LoadingState widget'ı render edilmiş olmalı (Shimmer skeleton)
      expect(find.byType(LoadingState), findsOneWidget);
    });

    testWidgets('hata durumunda hata mesajı görünür', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ActiveFaultsSection(
            activeFaults: AsyncError('Bağlantı hatası', StackTrace.empty),
            elevators: null,
          ),
        ),
      );

      expect(find.textContaining('Bağlantı hatası'), findsOneWidget);
    });

    testWidgets('boş liste gelince boş durum mesajı görünür', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ActiveFaultsSection(
            activeFaults: AsyncData([]),
            elevators: null,
          ),
        ),
      );

      expect(find.text('Aktif arıza bulunmuyor.'), findsOneWidget);
    });

    testWidgets("dolu liste gelince kart sayısı badge'inde yansır", (
      tester,
    ) async {
      final faults = [_fault(id: 'f1'), _fault(id: 'f2')];

      await tester.pumpWidget(
        _wrap(
          ActiveFaultsSection(
            activeFaults: AsyncData(faults),
            elevators: const [],
          ),
        ),
      );

      expect(find.text('2 Aktif'), findsOneWidget);
    });
  });
}
