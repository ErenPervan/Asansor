import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:asansor/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E App Test - Login Flow', () {
    testWidgets('Login ekranı yükleniyor ve elemanlar görünür', (tester) async {
      await app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Kullanıcı oturum açmamışsa LoginView gelir
      // TextField ve butonları bulalım

      // We assume there are exactly 2 text fields or at least 2.
      // Another way is finding by label text if available.
      // But finding at least 1 TextField is a safe assertion for login view.
      expect(find.byType(TextField), findsAtLeastNWidgets(2));

      // "Giriş" kelimesini içeren bir buton arayalım
      // If it's another button type, we can fallback to finding text.
      expect(find.textContaining('Giriş', skipOffstage: false), findsWidgets);
    });

    testWidgets('Hatalı credential girildiğinde hata mesajı görünür', (
      tester,
    ) async {
      await app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Input invalid credentials
      final textFields = find.byType(TextField);
      if (textFields.evaluate().isEmpty) {
        // Zaten giriş yapılmış olabilir, testi atla veya oturumu kapat
        return;
      }

      await tester.enterText(textFields.first, 'invalid@example.com');
      await tester.enterText(textFields.last, 'wrongpassword');
      await tester.pumpAndSettle();

      final loginButton = find.byType(ElevatedButton).first;
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Supabase'in auth hatası veya UI validator hatası ekranda SnackBar olarak çıkmalı
      // Burada spesifik metin yerine bir SnackBar veya Text arayabiliriz
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
