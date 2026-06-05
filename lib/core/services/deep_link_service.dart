import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final _appLinks = AppLinks();

  /// GoRouter instance'ı bağlar ve deep link stream'ini dinlemeye başlar.
  Future<void> initialize(GoRouter router) async {
    // Cold start (uygulama kapalıyken açılış): initial link al
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      debugPrint('[DeepLink] Cold start URI: $initialUri');
      _handleUri(router, initialUri);
    }

    // Warm start (uygulama arka planda): stream dinle
    _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('[DeepLink] Warm start URI: $uri');
        _handleUri(router, uri);
      },
      onError: (e) => debugPrint('[DeepLink] Stream error: $e'),
    );
  }

  void _handleUri(GoRouter router, Uri uri) {
    if (uri.scheme != 'asansor') return;
    // asansor://elevator/UUID → /elevator/UUID
    // asansor://fault/ID    → /fault/ID
    final path = '/${uri.host}${uri.path}';
    debugPrint('[DeepLink] Navigating to: $path');
    router.go(path);
  }
}
