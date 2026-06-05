import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asansor/core/widgets/shimmer_card.dart';
import '../../helpers/golden_test_utils.dart';

void main() {
  group('ShimmerCard Golden Test', () {
    testWidgets('default shimmer card', (tester) async {
      await tester.pumpWidget(pumpWithTheme(const ShimmerCard()));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/shimmer_card_default.png'),
      );
    });

    testWidgets('custom shimmer card', (tester) async {
      await tester.pumpWidget(
        pumpWithTheme(
          const ShimmerCard(width: 200, height: 50, borderRadius: 20),
        ),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/shimmer_card_custom.png'),
      );
    });
  });
}
