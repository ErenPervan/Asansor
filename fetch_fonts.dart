import 'dart:io';

void main() async {
  final client = HttpClient();
  final dir = Directory('assets/fonts');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  final files = {
    'NunitoSans-Regular.ttf': 'NunitoSans_7pt-Regular.ttf',
    'NunitoSans-Bold.ttf': 'NunitoSans_7pt-Bold.ttf',
    'NunitoSans-Italic.ttf': 'NunitoSans_7pt-Italic.ttf',
    'NunitoSans-BoldItalic.ttf': 'NunitoSans_7pt-BoldItalic.ttf',
  };

  final baseUrl = 'https://raw.githubusercontent.com/google/fonts/main/ofl/nunitosans/static/';

  for (final entry in files.entries) {
    final localName = entry.key;
    final remoteName = entry.value;
    final url = Uri.parse('$baseUrl$remoteName');
    // Using stdout.writeln instead of print to avoid lint warnings if any, or just standard print is fine in standalone tools.
    // However, to satisfy production print lints (which sometimes apply to bin/ or root files depending on rules), we can use stdout.writeln.
    stdout.writeln('Downloading $localName...');
    try {
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode == 200) {
        final bytes = await response.expand((chunk) => chunk).toList();
        await File('assets/fonts/$localName').writeAsBytes(bytes);
        stdout.writeln('Saved $localName');
      } else {
        stdout.writeln('Failed to download $localName: ${response.statusCode}');
      }
    } catch (e) {
      stdout.writeln('Error downloading $localName: $e');
    }
  }
  client.close();
  stdout.writeln('Done!');
}
