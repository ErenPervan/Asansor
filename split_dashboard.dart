// ignore_for_file: avoid_print
import 'dart:io';


void main() async {
  final baseDir = 'd:/Asansor/lib/features/admin/views';
  final widgetsDir = 'd:/Asansor/lib/features/admin/widgets/dashboard';

  final dir = Directory(widgetsDir);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  final dashboardFile = File('$baseDir/admin_dashboard_view.dart');
  final lines = await dashboardFile.readAsLines();

  int findLine(String pattern, [int startFrom = 0]) {
    for (int i = startFrom; i < lines.length; i++) {
      if (lines[i].startsWith(pattern)) {
        return i;
      }
    }
    return -1;
  }

  String extractClass(String className) {
    int startIdx = findLine('class $className');
    if (startIdx == -1) {
      startIdx = findLine('class $className<'); // handle generic classes
    }
    if (startIdx == -1) return '';
    
    // go back to grab comments/annotations right above the class
    int realStart = startIdx;
    while (realStart > 0 && (lines[realStart - 1].trim().isEmpty || lines[realStart - 1].trim().startsWith('//') || lines[realStart - 1].trim().startsWith('@'))) {
      realStart--;
    }

    int endIdx = lines.length;
    for (int i = startIdx + 1; i < lines.length; i++) {
      if (lines[i].startsWith('class ')) {
        endIdx = i;
        break;
      }
    }
    
    // adjust endIdx back past empty lines
    while (endIdx > realStart && lines[endIdx - 1].trim().isEmpty) {
      endIdx--;
    }

    return lines.sublist(realStart, endIdx).join('\n');
  }

  const commonImports = '''import 'package:flutter/material.dart';
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

  final files = {
    'dashboard_banners.dart': {
      'classes': ['_ConflictBanner', '_AddElevatorBanner', '_ErrorBanner'],
      'publics': ['ConflictBanner', 'AddElevatorBanner', 'ErrorBanner']
    },
    'dashboard_stats.dart': {
      'classes': ['_StatsGrid', '_StatCard'],
      'publics': ['DashboardStatsGrid', 'DashboardStatCard']
    },
    'dashboard_map_card.dart': {
      'classes': ['_MapPreviewCard'],
      'publics': ['DashboardMapCard']
    },
    'dashboard_user_cards.dart': {
      'classes': ['_UserManagementCard', '_TechnicianDirCard'],
      'publics': ['UserManagementCard', 'TechnicianDirCard']
    },
    'dashboard_calendar_cards.dart': {
      'classes': ['_CalendarCard', '_MasterCalendarCard'],
      'publics': ['DashboardCalendarCard', 'MasterCalendarCard']
    },
    'dashboard_schedule.dart': {
      'classes': ['_ScheduleList', '_ScheduleCard'],
      'publics': ['DashboardScheduleList', 'DashboardScheduleCard']
    },
    'dashboard_misc_cards.dart': {
      'classes': ['_ChecklistCard', '_StatisticsCard'],
      'publics': ['ChecklistCard', 'StatisticsCard']
    }
  };

  for (final entry in files.entries) {
    final filename = entry.key;
    final config = entry.value;
    final classes = config['classes'] as List<String>;
    final publics = config['publics'] as List<String>;
    
    List<String> contents = [];
    for (int i = 0; i < classes.length; i++) {
      String clsContent = extractClass(classes[i]);
      // Also extract the state class if it exists
      String stateClass = '_${classes[i].replaceFirst('_', '')}State';
      String stateContent = extractClass(stateClass);
      
      contents.add(clsContent);
      if (stateContent.isNotEmpty) contents.add(stateContent);
    }
    
    String content = contents.join('\n\n');
    
    for (int i = 0; i < classes.length; i++) {
      final cls = classes[i];
      final publicCls = publics[i];
      content = content.replaceAll(cls, publicCls);
      content = content.replaceAll('State<$cls>', 'State<$publicCls>');
    }
    
    final outFile = File('$widgetsDir/$filename');
    await outFile.writeAsString('$commonImports\n$content');
    print('Created $filename');
  }

  // Rewrite admin_dashboard_view.dart
  // Keep everything before the first extracted class (_ConflictBanner)
  int conflictBannerIdx = findLine('class _ConflictBanner');
  
  if (conflictBannerIdx != -1) {
    // We need to keep only the AdminDashboardView class
    // Find where AdminDashboardView ends. It's before _ConflictBanner
    int endOfMainView = conflictBannerIdx;
    while (endOfMainView > 0 && (lines[endOfMainView - 1].trim().isEmpty || lines[endOfMainView - 1].trim().startsWith('//'))) {
      endOfMainView--;
    }

    var newDashboardView = lines.sublist(0, endOfMainView).join('\n');
    
    for (final config in files.values) {
      final classes = config['classes'] as List<String>;
      final publics = config['publics'] as List<String>;
      for (int i = 0; i < classes.length; i++) {
        final cls = classes[i];
        final publicCls = publics[i];
        newDashboardView = newDashboardView.replaceAll('$cls(', '$publicCls(');
        newDashboardView = newDashboardView.replaceAll('$cls.', '$publicCls.'); 
        newDashboardView = newDashboardView.replaceAll('<$cls>', '<$publicCls>'); 
      }
    }
    
    final imports = files.keys.map((f) => "import '../widgets/dashboard/$f';").join('\n');
    
    final newDashboardLines = newDashboardView.split('\n');
    int lastImportIdx = 0;
    for (int i = 0; i < newDashboardLines.length; i++) {
      if (newDashboardLines[i].startsWith('import ')) {
        lastImportIdx = i;
      }
    }
    
    newDashboardLines.insert(lastImportIdx + 1, imports);
    
    await dashboardFile.writeAsString(newDashboardLines.join('\n'));
    print('Updated admin_dashboard_view.dart');
  }
}
