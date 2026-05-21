// ignore_for_file: avoid_print
import 'dart:io';


void main() async {
  final baseDir = 'd:/Asansor/lib/features/admin';
  final filesToFix = [
    '$baseDir/views/admin_calendar_view.dart',
    '$baseDir/widgets/calendar/calendar_task_card.dart',
    '$baseDir/widgets/calendar/calendar_assign_sheet.dart',
    '$baseDir/widgets/calendar/calendar_pickers.dart',
  ];

  for (final path in filesToFix) {
    final file = File(path);
    if (!await file.exists()) continue;

    var content = await file.readAsString();
    
    // Replace function calls
    content = content.replaceAll('_priorityColor', 'getPriorityColor');
    content = content.replaceAll('_priorityLabel', 'getPriorityLabel');
    content = content.replaceAll('_statusColor', 'getStatusColor');
    content = content.replaceAll('_statusLabel', 'getStatusLabel');
    content = content.replaceAll('_fmtTime', 'formatTime');

    // Replace classes that were missed by split_calendar.dart
    content = content.replaceAll('_ElevatorPickerDialog', 'ElevatorPickerDialog');
    content = content.replaceAll('_TechnicianPickerDialog', 'TechnicianPickerDialog');
    content = content.replaceAll('_PrioritySelector', 'PrioritySelector');
    content = content.replaceAll('_PickerField', 'PickerField');

    // Add import to helpers if not there and it's a widget file
    if (path.contains('widgets/calendar')) {
      if (!content.contains("import 'calendar_helpers.dart';")) {
        content = content.replaceFirst("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'calendar_helpers.dart';");
      }
    }

    await file.writeAsString(content);
    print('Fixed helpers in \$path');
  }

  // Remove the old helpers from admin_calendar_view.dart
  final viewFile = File('$baseDir/views/admin_calendar_view.dart');
  final lines = await viewFile.readAsLines();
  int startIdx = -1;
  int endIdx = -1;
  
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].startsWith('Color getPriorityColor(String p) {')) {
      startIdx = i;
    }
    if (lines[i].startsWith('ElevatorModel? _findElevator')) {
      endIdx = i;
    }
  }

  if (startIdx != -1 && endIdx != -1) {
    // Go back to remove the comment // ── Priority helpers ──
    int realStart = startIdx;
    while (realStart > 0 && (lines[realStart - 1].trim().isEmpty || lines[realStart - 1].trim().startsWith('//'))) {
      realStart--;
    }
    
    final newLines = [...lines.sublist(0, realStart), ...lines.sublist(endIdx)];
    await viewFile.writeAsString(newLines.join('\n'));
    print('Removed old helpers from admin_calendar_view.dart');
  }
}
