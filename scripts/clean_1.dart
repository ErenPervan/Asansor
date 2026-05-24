// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final files = [
    r"d:\Asansor\lib\features\admin\widgets\calendar\calendar_assign_sheet.dart",
    r"d:\Asansor\lib\features\elevator\widgets\detail\elevator_maintenance_history.dart",
    r"d:\Asansor\lib\features\elevator\widgets\detail\log_maintenance_sheet.dart",
    r"d:\Asansor\lib\features\elevator\widgets\detail\report_fault_sheet.dart",
    r"d:\Asansor\lib\features\customer\views\customer_dashboard_view.dart",
  ];

  for (final fp in files) {
    try {
      final file = File(fp);
      if (!file.existsSync()) continue;
      String content = file.readAsStringSync();

      // Let's replace `\1` based on context
      content = content.replaceAll(r'\1', 'backgroundColor: AppColors.error,');

      file.writeAsStringSync(content);
      print("Fixed \\1 in $fp");
    } catch (e) {
      print("Error: $e");
    }
  }
}
