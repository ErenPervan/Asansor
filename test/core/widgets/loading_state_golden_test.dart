import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import '../../helpers/golden_test_utils.dart';

void main() {
  group('LoadingState Golden Test', () {
    testWidgets('default loading state', (tester) async {
      await tester.pumpWidget(pumpWithTheme(const LoadingState()));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/loading_state_default.png'),
      );
    });

    testWidgets('loading state as single card', (tester) async {
      await tester.pumpWidget(pumpWithTheme(const LoadingState(isList: false)));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/loading_state_single.png'),
      );
    });
  });
}
