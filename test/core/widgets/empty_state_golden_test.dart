import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asansor/core/widgets/empty_state.dart';
import '../../helpers/golden_test_utils.dart';

void main() {
  group('EmptyState Golden Test', () {
    testWidgets('default empty state', (tester) async {
      await tester.pumpWidget(pumpWithTheme(const EmptyState(message: 'Veri bulunamadı', icon: Icons.info_outline)));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/empty_state_default.png'),
      );
    });

    testWidgets('empty state with custom icon', (tester) async {
      await tester.pumpWidget(pumpWithTheme(const EmptyState(message: 'Liste boş', icon: Icons.list)));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/empty_state_custom.png'),
      );
    });
  });
}
