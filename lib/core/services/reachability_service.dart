import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ReachabilityService {
  Future<bool> checkSupabase(String url) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.head(uri).timeout(const Duration(seconds: 5));
      return response.statusCode < 500;
    } catch (e) {
      debugPrint('[ReachabilityService] Supabase unreachable: $e');
      return false;
    }
  }
}
