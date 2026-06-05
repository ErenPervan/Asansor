import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asansor/core/widgets/offline_banner.dart';
import 'package:asansor/core/providers/connectivity_providers.dart';
import '../../helpers/golden_test_utils.dart';

void main() {
  group('OfflineBanner Golden Test', () {
    testWidgets('offline banner visible when offline', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isOnlineProvider.overrideWithValue(false),
          ],
          child: pumpWithTheme(const OfflineBanner()),
        ),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/offline_banner_visible.png'),
      );
    });

    testWidgets('offline banner hidden when online', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isOnlineProvider.overrideWithValue(true),
          ],
          child: pumpWithTheme(const OfflineBanner()),
        ),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/offline_banner_hidden.png'),
      );
    });
  });
}
