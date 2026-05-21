// ignore_for_file: avoid_print
import 'dart:io';


void main() async {
  final widgetsDir = 'd:/Asansor/lib/features/admin/widgets/dashboard';
  final dir = Directory(widgetsDir);
  
  final commonImports = '''import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/connectivity_providers.dart';
import '../../../../core/services/sync_queue_service.dart';
import '../../../elevator/models/elevator_model.dart';
import '../../../fault/models/fault_report_model.dart';
import '../../models/schedule_model.dart';
import '../../../fault/providers/fault_providers.dart';
import '../../../elevator/providers/elevator_providers.dart';
import '../../providers/admin_providers.dart';
import '../../../maintenance/providers/maintenance_providers.dart';
import '../../providers/admin_analytics_provider.dart';
import '../../providers/admin_technician_provider.dart';
import '../../providers/profile_providers.dart';
import '../../models/profile_model.dart';
''';

  await for (final file in dir.list()) {
    if (file is File && file.path.endsWith('.dart')) {
      final lines = await file.readAsLines();
      
      int importEndIdx = 0;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].startsWith('import ')) {
          importEndIdx = i;
        } else if (lines[i].trim().isEmpty) {
          continue;
        } else {
          break; 
        }
      }
      
      final content = lines.sublist(importEndIdx + 1).join('\n');
      await file.writeAsString('$commonImports\n$content');
      print('Fixed imports in ${file.path}');
    }
  }
}
