// ignore_for_file: avoid_print
import 'dart:io';


void main() async {
  final baseDir = 'd:/Asansor/lib/features/elevator/views';
  final widgetsDir = 'd:/Asansor/lib/features/elevator/widgets/home';

  final dir = Directory(widgetsDir);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  final homeViewFile = File('$baseDir/home_view.dart');
  final lines = await homeViewFile.readAsLines();

  int findLine(String pattern) {
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].startsWith(pattern)) {
        return i;
      }
    }
    return -1;
  }

  String extractContent(String startClass, String? endClass) {
    int startIdx = findLine('class $startClass');
    if (startIdx == -1) return '';
    
    int endIdx = lines.length;
    if (endClass != null) {
      endIdx = findLine('class $endClass');
      if (endIdx == -1) endIdx = lines.length;
    }
    
    while (endIdx > startIdx && (lines[endIdx - 1].trim().isEmpty || lines[endIdx - 1].trim().startsWith('//'))) {
      endIdx--;
    }
    
    return lines.sublist(startIdx, endIdx).join('\n');
  }

  const commonImports = '''import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_flutter;
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/connectivity_providers.dart';
import '../../../core/services/sync_queue_service.dart';
import '../../elevator/models/elevator_model.dart';
import '../../fault/models/fault_report_model.dart';
import '../../admin/models/schedule_model.dart';
import '../../fault/providers/fault_providers.dart';
import '../../elevator/providers/elevator_providers.dart';
import '../../admin/providers/admin_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
''';

  final files = {
    'home_top_app_bar.dart': {
      'classes': ['_TopAppBar', '_SyncStatusButton', '_SyncSheet'],
      'end': '_ActiveFaultsSection'
    },
    'home_active_faults.dart': {
      'classes': ['_ActiveFaultsSection', '_FaultCard', '_FaultCardState'],
      'end': '_DailyAgendaSection'
    },
    'home_daily_agenda.dart': {
      'classes': ['_DailyAgendaSection', '_AgendaGroupHeader', '_AgendaTaskCard'],
      'end': '_StatsSection'
    },
    'home_stats_section.dart': {
      'classes': ['_StatsSection', '_ElevatorsShortcutCard'],
      'end': '_QrFab'
    },
    'home_qr_fab.dart': {
      'classes': ['_QrFab'],
      'end': '_BottomNavBar'
    }
  };

  for (final entry in files.entries) {
    final filename = entry.key;
    final config = entry.value;
    final classes = config['classes'] as List<String>;
    final endClass = config['end'] as String;
    
    String content = extractContent(classes[0], endClass);
    
    for (final cls in classes) {
      final publicCls = cls.replaceFirst('_', '');
      content = content.replaceAll(cls, publicCls);
      content = content.replaceAll('State<$cls>', 'State<$publicCls>');
    }
    
    final outFile = File('$widgetsDir/$filename');
    await outFile.writeAsString('$commonImports\n$content');
    print('Created $filename');
  }

  // Remove extracted classes from home_view.dart
  final startIdx = findLine('class _TopAppBar');
  final endIdx = findLine('class _BottomNavBar');
  
  if (startIdx != -1 && endIdx != -1) {
    var newHomeView = [...lines.sublist(0, startIdx), ...lines.sublist(endIdx)].join('\n');
    
    for (final config in files.values) {
      final classes = config['classes'] as List<String>;
      for (final cls in classes) {
        final publicCls = cls.replaceFirst('_', '');
        newHomeView = newHomeView.replaceAll('$cls(', '$publicCls(');
      }
    }
    
    final imports = files.keys.map((f) => "import '../widgets/home/$f';").join('\n');
    
    final newHomeLines = newHomeView.split('\n');
    int lastImportIdx = 0;
    for (int i = 0; i < newHomeLines.length; i++) {
      if (newHomeLines[i].startsWith('import ')) {
        lastImportIdx = i;
      }
    }
    
    newHomeLines.insert(lastImportIdx + 1, imports);
    newHomeLines.insert(lastImportIdx + 2, "import '../../../core/widgets/app_bottom_nav_bar.dart';");
    
    String finalHomeView = newHomeLines.join('\n');
    finalHomeView = finalHomeView.replaceAll('const _BottomNavBar()', 'const AppBottomNavBar(currentIndex: 3)');
    
    // Comment out remaining bottom nav bar code from bottom
    int bottomNavStart = findLine('class _BottomNavBar');
    if (bottomNavStart != -1) {
        finalHomeView = finalHomeView.substring(0, finalHomeView.indexOf('class _BottomNavBar'));
    }

    await homeViewFile.writeAsString(finalHomeView);
    print('Updated home_view.dart');
  }
}
