// ignore_for_file: avoid_print
import 'dart:io';

void main() async {
  final baseDir = 'd:/Asansor/lib/features/admin/views';
  final widgetsDir = 'd:/Asansor/lib/features/admin/widgets/calendar';

  final dir = Directory(widgetsDir);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  final calendarFile = File('$baseDir/admin_calendar_view.dart');
  final lines = await calendarFile.readAsLines();

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
    if (startIdx == -1) return '';

    int realStart = startIdx;
    while (realStart > 0 &&
        (lines[realStart - 1].trim().isEmpty ||
            lines[realStart - 1].trim().startsWith('//') ||
            lines[realStart - 1].trim().startsWith('@'))) {
      realStart--;
    }

    int endIdx = lines.length;
    for (int i = startIdx + 1; i < lines.length; i++) {
      if (lines[i].startsWith('class ')) {
        endIdx = i;
        break;
      }
    }

    while (endIdx > realStart && lines[endIdx - 1].trim().isEmpty) {
      endIdx--;
    }

    return lines.sublist(realStart, endIdx).join('\n');
  }

  const commonImports = '''import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../elevator/models/elevator_model.dart';
import '../../../elevator/providers/elevator_providers.dart';
import '../../models/profile_model.dart';
import '../../models/schedule_model.dart';
import '../../providers/admin_providers.dart';
import '../../providers/profile_providers.dart';
''';

  final files = {
    'calendar_task_card.dart': {
      'classes': ['_CalendarTaskCard', '_PriorityBadge', '_StatusBadge'],
      'publics': ['CalendarTaskCard', 'PriorityBadge', 'StatusBadge'],
    },
    'calendar_assign_sheet.dart': {
      'classes': ['_AssignTaskSheet', '_PrioritySelector', '_PickerField'],
      'publics': ['AssignTaskSheet', 'PrioritySelector', 'PickerField'],
    },
    'calendar_pickers.dart': {
      'classes': ['_ElevatorPickerDialog', '_TechnicianPickerDialog'],
      'publics': ['ElevatorPickerDialog', 'TechnicianPickerDialog'],
    },
  };

  for (final entry in files.entries) {
    final filename = entry.key;
    final config = entry.value;
    final classes = config['classes'] as List<String>;
    final publics = config['publics'] as List<String>;

    List<String> contents = [];
    for (int i = 0; i < classes.length; i++) {
      String clsContent = extractClass(classes[i]);
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

  // Rewrite admin_calendar_view.dart
  int endOfMainView = findLine('class _CalendarTaskCard');
  if (endOfMainView != -1) {
    while (endOfMainView > 0 &&
        (lines[endOfMainView - 1].trim().isEmpty ||
            lines[endOfMainView - 1].trim().startsWith('//'))) {
      endOfMainView--;
    }

    var newCalendarView = lines.sublist(0, endOfMainView).join('\n');

    for (final config in files.values) {
      final classes = config['classes'] as List<String>;
      final publics = config['publics'] as List<String>;
      for (int i = 0; i < classes.length; i++) {
        final cls = classes[i];
        final publicCls = publics[i];
        newCalendarView = newCalendarView.replaceAll('$cls(', '$publicCls(');
        newCalendarView = newCalendarView.replaceAll('$cls.', '$publicCls.');
        newCalendarView = newCalendarView.replaceAll('<$cls>', '<$publicCls>');
      }
    }

    final imports = files.keys
        .map((f) => "import '../widgets/calendar/$f';")
        .join('\n');

    final newCalendarLines = newCalendarView.split('\n');
    int lastImportIdx = 0;
    for (int i = 0; i < newCalendarLines.length; i++) {
      if (newCalendarLines[i].startsWith('import ')) {
        lastImportIdx = i;
      }
    }

    newCalendarLines.insert(lastImportIdx + 1, imports);

    await calendarFile.writeAsString(newCalendarLines.join('\n'));
    print('Updated admin_calendar_view.dart');
  }
}
