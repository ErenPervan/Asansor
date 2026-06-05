import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asansor/core/widgets/error_state.dart';
import '../../helpers/golden_test_utils.dart';

void main() {
  group('ErrorState Golden Test', () {
    testWidgets('error state with message', (tester) async {
      await tester.pumpWidget(pumpWithTheme(const ErrorState(message: 'Bir hata oluştu.')));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/error_state_default.png'),
      );
    });

    testWidgets('error state with retry', (tester) async {
      await tester.pumpWidget(pumpWithTheme(ErrorState(message: 'Bağlantı hatası', onRetry: () {})));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/error_state_with_retry.png'),
      );
    });
  });
}
