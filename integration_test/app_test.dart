import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:asansor/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E App Test', () {
    testWidgets('Uygulama başarıyla başlatılabiliyor mu ve login ekranı görünüyor mu?', (tester) async {
      await app.main();

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Asansor metnini ara (Login sayfasında 'Asansor' Text widget'ı var)
      expect(find.text('Asansor'), findsWidgets);

      // Email field ve Password field bulunmalı
      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);

      // Giriş yap butonu bulunmalı (FilledButton)
      final loginButton = find.byType(FilledButton);
      expect(loginButton, findsOneWidget);
      
      // Boşken submit etmeyi deneyelim
      await tester.tap(loginButton);
      await tester.pumpAndSettle();
    });
  });
}
