import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:asansor/core/widgets/app_bottom_nav_bar.dart';
import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/features/admin/providers/profile_providers.dart';
import '../../helpers/golden_test_utils.dart';
import '../../helpers/test_factories.dart';
import '../../helpers/test_mocks.dart';

void main() {
  late MockStatefulNavigationShell mockNavigationShell;

  setUp(() {
    mockNavigationShell = MockStatefulNavigationShell();
    when(() => mockNavigationShell.currentIndex).thenReturn(0);
    when(
      () => mockNavigationShell.goBranch(
        any(),
        initialLocation: any(named: 'initialLocation'),
      ),
    ).thenAnswer((_) {});
  });

  group('AppBottomNavBar Widget Test', () {
    testWidgets('admin sees all tabs active', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith(
              (ref) => TestFactories.createProfile(role: UserRole.admin),
            ),
          ],
          child: pumpWithTheme(
            Scaffold(
              bottomNavigationBar: AppBottomNavBar(
                navigationShell: mockNavigationShell,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Filo'.toUpperCase()), findsOneWidget);
      expect(find.text('Arızalar'.toUpperCase()), findsOneWidget);
      expect(find.text('Program'.toUpperCase()), findsOneWidget);
      expect(find.text('Günlük'.toUpperCase()), findsOneWidget);

      // Verify Tooltip is NOT present for 'PROGRAM'
      final programIcon = find.text('Program'.toUpperCase());
      final tooltipFinder = find.ancestor(
        of: programIcon,
        matching: find.byType(Tooltip),
      );
      expect(tooltipFinder, findsNothing);

      // Verify Opacity is NOT present
      final opacityFinder = find.ancestor(
        of: programIcon,
        matching: find.byType(Opacity),
      );
      expect(opacityFinder, findsNothing);
    });

    testWidgets('technician does not see program tab', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith(
              (ref) => TestFactories.createProfile(role: UserRole.technician),
            ),
          ],
          child: pumpWithTheme(
            Scaffold(
              bottomNavigationBar: AppBottomNavBar(
                navigationShell: mockNavigationShell,
              ),
            ),
          ),
        ),
      );

      final programIcon = find.text('Program'.toUpperCase());
      expect(programIcon, findsNothing);
    });

    testWidgets('customer does not see program tab', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith(
              (ref) => TestFactories.createProfile(role: UserRole.customer),
            ),
          ],
          child: pumpWithTheme(
            Scaffold(
              bottomNavigationBar: AppBottomNavBar(
                navigationShell: mockNavigationShell,
              ),
            ),
          ),
        ),
      );

      final programIcon = find.text('Program'.toUpperCase());
      expect(programIcon, findsNothing);
    });

    testWidgets('active tab color is primary', (tester) async {
      when(() => mockNavigationShell.currentIndex).thenReturn(1); // ARIZALAR

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith(
              (ref) => TestFactories.createProfile(role: UserRole.admin),
            ),
          ],
          child: pumpWithTheme(
            Scaffold(
              bottomNavigationBar: AppBottomNavBar(
                navigationShell: mockNavigationShell,
              ),
            ),
          ),
        ),
      );

      final arizalarText = tester.widget<Text>(
        find.text('Arızalar'.toUpperCase()),
      );
      final filoText = tester.widget<Text>(find.text('Filo'.toUpperCase()));

      // The active tab should have fontWeight w700, inactive w500
      expect(arizalarText.style?.fontWeight, FontWeight.w700);
      expect(filoText.style?.fontWeight, FontWeight.w500);

      // The active tab should have different color than inactive
      expect(arizalarText.style?.color, isNot(equals(filoText.style?.color)));
    });

    testWidgets('goBranch is called on tap', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith(
              (ref) => TestFactories.createProfile(role: UserRole.admin),
            ),
          ],
          child: pumpWithTheme(
            Scaffold(
              bottomNavigationBar: AppBottomNavBar(
                navigationShell: mockNavigationShell,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Arızalar'.toUpperCase()));
      await tester.pumpAndSettle();

      verify(
        () => mockNavigationShell.goBranch(1, initialLocation: false),
      ).called(1);
    });
  });
}
