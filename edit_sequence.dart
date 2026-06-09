import 'dart:io';

void main(List<String> args) {
  final file = File(args[0]);
  final lines = file.readAsLinesSync();
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].startsWith('pick')) {
      lines[i] = lines[i].replaceFirst('pick', 'edit');
      break;
    }
  }
  file.writeAsStringSync(lines.join('\n') + '\n');
}
