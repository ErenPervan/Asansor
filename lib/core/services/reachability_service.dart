import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:asansor/core/constants/supabase_constants.dart';

enum ReachabilityStatus {
  online,
  offline,
  transientError,
  serverError,
  captivePortal,
}

class ReachabilityService {
  ReachabilityService._();

  static final ReachabilityService instance = ReachabilityService._();

  static const Duration _timeout = Duration(seconds: 5);

  /// Tests reachability to Supabase by sending a HEAD request to the health/status endpoint or the root URL.
  Future<ReachabilityStatus> checkReachability() async {
    try {
      final uri = Uri.parse(SupabaseConstants.supabaseUrl);

      final client = HttpClient();
      client.connectionTimeout = _timeout;

      final request = await client.headUrl(uri);
      final response = await request.close();

      final statusCode = response.statusCode;

      if (statusCode >= 200 && statusCode < 400) {
        // If it's a redirect to a non-supabase URL, it might be a captive portal
        if (response.isRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location != null && !location.contains(uri.host)) {
            return ReachabilityStatus.captivePortal;
          }
        }
        return ReachabilityStatus.online;
      } else if (statusCode >= 500) {
        return ReachabilityStatus.serverError;
      } else {
        // 4xx errors technically mean the server is reachable
        return ReachabilityStatus.online;
      }
    } on SocketException catch (_) {
      return ReachabilityStatus.offline;
    } on TimeoutException catch (_) {
      return ReachabilityStatus.transientError;
    } catch (e) {
      debugPrint('[ReachabilityService] Unknown error: $e');
      return ReachabilityStatus.transientError;
    }
  }
}
