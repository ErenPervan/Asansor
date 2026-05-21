// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final files = [
    r"d:\Asansor\lib\features\admin\views\admin_master_calendar_view.dart",
    r"d:\Asansor\lib\features\admin\views\checklist_management_view.dart",
    r"d:\Asansor\lib\features\admin\views\elevator_qr_view.dart",
    r"d:\Asansor\lib\features\admin\views\technician_management_view.dart",
    r"d:\Asansor\lib\features\admin\views\user_management_view.dart",
    r"d:\Asansor\lib\features\admin\widgets\calendar\calendar_assign_sheet.dart",
    r"d:\Asansor\lib\features\customer\views\customer_dashboard_view.dart",
    r"d:\Asansor\lib\features\elevator\views\conflict_resolution_view.dart",
    r"d:\Asansor\lib\features\elevator\widgets\detail\elevator_maintenance_history.dart",
    r"d:\Asansor\lib\features\elevator\widgets\detail\log_maintenance_sheet.dart",
    r"d:\Asansor\lib\features\elevator\widgets\detail\report_fault_sheet.dart",
    r"d:\Asansor\lib\features\elevator\widgets\home\home_top_app_bar.dart",
  ];

  for (final fp in files) {
    try {
      final file = File(fp);
      if (!file.existsSync()) {
        print("Skipping missing file: $fp");
        continue;
      }
      
      String content = file.readAsStringSync();

      if (content.contains("duration: AppDurations")) {
        continue;
      }

      final importStmt = "import 'package:asansor/core/constants/app_durations.dart';\n";
      
      String newContent = content;
      newContent = newContent.replaceAll(
          RegExp(r'(backgroundColor:\s*AppColors\.error,?)'), 
          r'\1' '\n          duration: AppDurations.snackBarError,');
      newContent = newContent.replaceAll(
          RegExp(r'(backgroundColor:\s*AppColors\.success,?)'), 
          r'\1' '\n          duration: AppDurations.snackBarSuccess,');
      newContent = newContent.replaceAll(
          RegExp(r'(backgroundColor:\s*AppColors\.primary,?)'), 
          r'\1' '\n          duration: AppDurations.snackBarInfo,');
      
      if (newContent != content) {
        if (!newContent.contains("app_durations.dart")) {
          int importIdx = newContent.indexOf('import ');
          if (importIdx != -1) {
            newContent = newContent.substring(0, importIdx) + importStmt + newContent.substring(importIdx);
          } else {
            newContent = importStmt + newContent;
          }
        }
        
        file.writeAsStringSync(newContent);
        print("Updated $fp");
      }
    } catch (e) {
      print("Error processing $fp: $e");
    }
  }
}
