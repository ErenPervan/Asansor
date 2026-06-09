import 'package:asansor/core/views/not_found_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('Deep Link & Router Tests', () {
    testWidgets('NotFoundView renders correctly', (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/error',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/error',
            builder: (context, state) => const NotFoundView(),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      // Verify that the title is "Asansor"
      expect(find.text('Asansor'), findsOneWidget);

      // Verify that the "Sayfa Bulunamadı" message exists
      expect(find.text('Sayfa Bulunamadı'), findsOneWidget);

      // Verify "Ana Sayfaya Dön" button exists
      expect(find.text('Ana Sayfaya Dön'), findsOneWidget);
    });
  });
}
