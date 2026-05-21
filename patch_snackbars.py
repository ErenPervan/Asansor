import os
import re

files = [
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
]

def process_file(fp):
    try:
        with open(fp, "r", encoding="utf-8") as f:
            content = f.read()

        if "duration: AppDurations" in content:
            return

        import_stmt = "import 'package:asansor/core/constants/app_durations.dart';"
        
        # Very simple strategy: if it has `showSnackBar(SnackBar(`, let's just insert duration manually based on colors
        
        # Replace occurrences
        new_content = content
        new_content = re.sub(r'(backgroundColor:\s*AppColors\.error,?)', r'\1\n          duration: AppDurations.snackBarError,', new_content)
        new_content = re.sub(r'(backgroundColor:\s*AppColors\.success,?)', r'\1\n          duration: AppDurations.snackBarSuccess,', new_content)
        new_content = re.sub(r'(backgroundColor:\s*AppColors\.primary,?)', r'\1\n          duration: AppDurations.snackBarInfo,', new_content)
        
        # Check for unhandled SnackBars
        # Find all SnackBar(
        unhandled = False
        snackbars = re.findall(r'SnackBar\([^)]+\)', new_content, flags=re.DOTALL)
        for sb in snackbars:
            if 'duration:' not in sb:
                print(f"Warning: unhandled SnackBar in {fp}")
                unhandled = True
        
        if new_content != content:
            if import_stmt not in new_content:
                imports = list(re.finditer(r"^import\s+['\"].*?['\"];", new_content, flags=re.MULTILINE))
                if imports:
                    last_import = imports[-1]
                    idx = last_import.end()
                    new_content = new_content[:idx] + "\n" + import_stmt + new_content[idx:]
            
            with open(fp, "w", encoding="utf-8") as f:
                f.write(new_content)
            print(f"Updated {fp}")
    except Exception as e:
        print(f"Error processing {fp}: {e}")

for fp in files:
    process_file(fp)
