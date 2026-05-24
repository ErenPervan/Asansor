// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final files = [
    r"d:\Asansor\lib\features\admin\widgets\calendar\calendar_assign_sheet.dart",
    r"d:\Asansor\lib\features\elevator\widgets\detail\elevator_maintenance_history.dart",
    r"d:\Asansor\lib\features\elevator\widgets\detail\log_maintenance_sheet.dart",
    r"d:\Asansor\lib\features\elevator\widgets\detail\report_fault_sheet.dart",
  ];

  for (final fp in files) {
    try {
      final file = File(fp);
      if (!file.existsSync()) continue;

      String content = file.readAsStringSync();

      content = content.replaceAll(
        '\n          duration: AppDurations.snackBarError,',
        '',
      );
      content = content.replaceAll(
        '\n          duration: AppDurations.snackBarSuccess,',
        '',
      );
      content = content.replaceAll(
        '\n          duration: AppDurations.snackBarInfo,',
        '',
      );

      file.writeAsStringSync(content);
      print("Fixed $fp");
    } catch (e) {
      print("Error processing $fp: $e");
    }
  }
}
