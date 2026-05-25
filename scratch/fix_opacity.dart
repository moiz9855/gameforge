import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    try {
      var content = file.readAsStringSync();
      if (content.contains('.withOpacity(')) {
        content = content.replaceAll('.withOpacity(', '.withValues(alpha: ');
        file.writeAsStringSync(content);
        print('Fixed ${file.path}');
      }
    } catch (e) {
      print('Error on ${file.path}: $e');
    }
  }
}
