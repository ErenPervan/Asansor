import os
import sys

BASE_DIR = r"d:\Asansor\lib\features\elevator\views"
WIDGETS_DIR = r"d:\Asansor\lib\features\elevator\widgets\home"

if not os.path.exists(WIDGETS_DIR):
    os.makedirs(WIDGETS_DIR)

with open(os.path.join(BASE_DIR, "home_view.dart"), "r", encoding="utf-8") as f:
    lines = f.readlines()

def find_line(pattern):
    for i, line in enumerate(lines):
        if line.startswith(pattern):
            return i
    return -1

def extract_content(start_class, end_class=None):
    start_idx = find_line(f"class {start_class}")
    if start_idx == -1: return ""
    if end_class:
        end_idx = find_line(f"class {end_class}")
        if end_idx == -1: end_idx = len(lines)
    else:
        end_idx = len(lines)
    
    # Exclude the exact line of end_class, but include all leading up to it
    # wait, there might be comments or helpers before end_class.
    # It's better to just search for the previous line.
    while end_idx > start_idx and lines[end_idx-1].strip() == "" or lines[end_idx-1].startswith("//"):
        end_idx -= 1
        
    return "".join(lines[start_idx:end_idx])

COMMON_IMPORTS = """import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_flutter;
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/connectivity_providers.dart';
import '../../../core/services/sync_queue_service.dart';
import '../../elevator/models/elevator_model.dart';
import '../../fault/models/fault_report_model.dart';
import '../../admin/models/schedule_model.dart';
"""

files = {
    "home_top_app_bar.dart": {
        "classes": ["_TopAppBar", "_SyncStatusButton", "_SyncSheet"],
        "end": "_ActiveFaultsSection"
    },
    "home_active_faults.dart": {
        "classes": ["_ActiveFaultsSection", "_FaultCard", "_FaultCardState"],
        "end": "_DailyAgendaSection"
    },
    "home_daily_agenda.dart": {
        "classes": ["_DailyAgendaSection", "_AgendaGroupHeader", "_AgendaTaskCard"],
        "end": "_StatsSection"
    },
    "home_stats_section.dart": {
        "classes": ["_StatsSection", "_ElevatorsShortcutCard"],
        "end": "_QrFab"
    },
    "home_qr_fab.dart": {
        "classes": ["_QrFab"],
        "end": "_BottomNavBar"
    }
}

for filename, config in files.items():
    start_class = config["classes"][0]
    end_class = config["end"]
    content = extract_content(start_class, end_class)
    
    # Replace private class names with public ones
    for cls in config["classes"]:
        public_cls = cls.replace("_", "", 1)
        content = content.replace(cls, public_cls)
        # Also fix State classes
        content = content.replace(f"State<{cls}>", f"State<{public_cls}>")
        
    out_path = os.path.join(WIDGETS_DIR, filename)
    with open(out_path, "w", encoding="utf-8") as out_f:
        out_f.write(COMMON_IMPORTS + "\n" + content)
    print(f"Created {filename}")

# Remove extracted classes from home_view.dart
start_idx = find_line("class _TopAppBar")
end_idx = find_line("class _BottomNavBar")
new_home_view = "".join(lines[:start_idx]) + "".join(lines[end_idx:])
# Wait, we need to replace the private class usages with public ones in new_home_view
for config in files.values():
    for cls in config["classes"]:
        public_cls = cls.replace("_", "", 1)
        new_home_view = new_home_view.replace(cls + "(", public_cls + "(")

# Add imports to home_view.dart
imports = "\n".join([f"import '../widgets/home/{f}';" for f in files.keys()])
# find last import
last_import_idx = 0
for i, line in enumerate(new_home_view.splitlines()):
    if line.startswith("import "):
        last_import_idx = i

new_home_lines = new_home_view.splitlines()
new_home_lines.insert(last_import_idx + 1, imports)
new_home_lines.insert(last_import_idx + 2, "import '../../../core/widgets/app_bottom_nav_bar.dart';")

# Replace _BottomNavBar with AppBottomNavBar
final_home_view = "\\n".join(new_home_lines)
final_home_view = final_home_view.replace("const _BottomNavBar()", "const AppBottomNavBar(currentIndex: 3)")
final_home_view = final_home_view.replace("class _BottomNavBar", "// class _BottomNavBar")
final_home_view = final_home_view.replace("class _NavItem", "// class _NavItem")

with open(os.path.join(BASE_DIR, "home_view.dart"), "w", encoding="utf-8") as f:
    f.write(final_home_view)
print("Updated home_view.dart")
