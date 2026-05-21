// ignore_for_file: avoid_print
import 'dart:io';

void main() async {
  final baseDir = 'd:/Asansor/lib/features/elevator/views';
  final widgetsDir = 'd:/Asansor/lib/features/elevator/widgets/detail';

  final dir = Directory(widgetsDir);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  final detailViewFile = File('$baseDir/elevator_detail_view.dart');
  final lines = await detailViewFile.readAsLines();

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

    while (endIdx > startIdx &&
        (lines[endIdx - 1].trim().isEmpty ||
            lines[endIdx - 1].trim().startsWith('//'))) {
      endIdx--;
    }

    return lines.sublist(startIdx, endIdx).join('\n');
  }

  const commonImports = '''import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_flutter;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/connectivity_providers.dart';
import '../../../../core/services/sync_queue_service.dart';
import '../../models/elevator_model.dart';
import '../../../fault/models/fault_report_model.dart';
import '../../../admin/models/schedule_model.dart';
import '../../../fault/providers/fault_providers.dart';
import '../../providers/elevator_providers.dart';
import '../../../admin/providers/admin_providers.dart';
import '../../../maintenance/providers/maintenance_providers.dart';
''';

  final files = {
    'elevator_detail_header.dart': {
      'classes': ['_HeaderCard', '_MetaCell', '_StatusBadge'],
      'publics': [
        'ElevatorDetailHeader',
        'DetailMetaCell',
        'DetailStatusBadge',
      ],
      'end': '_ActionButtons',
    },
    'elevator_detail_actions.dart': {
      'classes': ['_ActionButtons', '_ActionCard'],
      'publics': ['ElevatorDetailActions', 'ElevatorActionCard'],
      'end': '_SystemMonitorSection',
    },
    'elevator_system_monitor.dart': {
      'classes': [
        '_SystemMonitorSection',
        '_NextMaintenanceContent',
        '_StatusIndicator',
        '_StatChip',
      ],
      'publics': [
        'SystemMonitorSection',
        'NextMaintenanceContent',
        'SystemStatusIndicator',
        'SystemStatChip',
      ],
      'end': '_MaintenanceHistorySection',
    },
    'elevator_maintenance_history.dart': {
      'classes': [
        '_MaintenanceHistorySection',
        '_MaintenanceHistorySectionState',
        '_TimelineItem',
        '_TimelineCard',
        '_Chip',
      ],
      'publics': [
        'MaintenanceHistorySection',
        'MaintenanceHistorySectionState',
        'TimelineItem',
        'TimelineCard',
        'StatusChip',
      ],
      'end': '_BottomNav',
    },
    'report_fault_sheet.dart': {
      'classes': ['ReportFaultSheet', '_ReportFaultSheetState'],
      'publics': ['ReportFaultSheet', '_ReportFaultSheetState'],
      'end': '_LogMaintenanceSheet',
    },
    'log_maintenance_sheet.dart': {
      'classes': ['_LogMaintenanceSheet', '_LogMaintenanceSheetState'],
      'publics': ['LogMaintenanceSheet', 'LogMaintenanceSheetState'],
      'end': '_ErrorBody',
    },
  };

  for (final entry in files.entries) {
    final filename = entry.key;
    final config = entry.value;
    final classes = config['classes'] as List<String>;
    final publics = config['publics'] as List<String>;
    final endClass = config['end'] as String;

    String content = extractContent(classes[0], endClass);

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

  // Remove extracted classes from elevator_detail_view.dart
  final startIdx = findLine('class _HeaderCard');
  final endIdx = findLine('class _BottomNav');
  final startSheet = findLine('class ReportFaultSheet');
  final endSheet = findLine('class _ErrorBody');

  if (startIdx != -1 && endIdx != -1 && startSheet != -1 && endSheet != -1) {
    var newDetailView = [
      ...lines.sublist(0, startIdx),
      ...lines.sublist(endIdx, startSheet),
      ...lines.sublist(endSheet),
    ].join('\n');

    for (final config in files.values) {
      final classes = config['classes'] as List<String>;
      final publics = config['publics'] as List<String>;
      for (int i = 0; i < classes.length; i++) {
        final cls = classes[i];
        final publicCls = publics[i];
        newDetailView = newDetailView.replaceAll('$cls(', '$publicCls(');
        newDetailView = newDetailView.replaceAll(
          '$cls.',
          '$publicCls.',
        ); // e.g. .new or .fromJson
        newDetailView = newDetailView.replaceAll('<$cls>', '<$publicCls>');
      }
    }

    final imports = files.keys
        .map((f) => "import '../widgets/detail/$f';")
        .join('\n');

    final newDetailLines = newDetailView.split('\n');
    int lastImportIdx = 0;
    for (int i = 0; i < newDetailLines.length; i++) {
      if (newDetailLines[i].startsWith('import ')) {
        lastImportIdx = i;
      }
    }

    newDetailLines.insert(lastImportIdx + 1, imports);
    newDetailLines.insert(
      lastImportIdx + 2,
      "import '../../../core/widgets/app_bottom_nav_bar.dart';",
    );

    String finalDetailView = newDetailLines.join('\n');

    // Replace BottomNav with AppBottomNavBar(currentIndex: 0) since this is detail view, maybe don't highlight any?
    // Actually detail view might not need bottom nav if it's pushed, but they had one.
    // _BottomNav() is const _BottomNav();
    finalDetailView = finalDetailView.replaceAll(
      'const _BottomNav()',
      'const AppBottomNavBar(currentIndex: -1)',
    );
    finalDetailView = finalDetailView.replaceAll(
      'class _BottomNav',
      '// class _BottomNav',
    );
    finalDetailView = finalDetailView.replaceAll(
      'class _NavItem',
      '// class _NavItem',
    );

    // Remove _BottomNav class lines completely to avoid analyzer errors since I'm doing substring replacement blindly
    // I can just remove them using regex or similar, but the comment out should work.

    await detailViewFile.writeAsString(finalDetailView);
    print('Updated elevator_detail_view.dart');
  }
}
