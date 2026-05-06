import 'dart:io';

void main() {
  final dir = Directory('lib');
  int removed = 0;
  
  void cleanTree(Directory dir) {
    for (var entity in dir.listSync()) {
      if (entity is Directory) {
        cleanTree(entity);
      }
    }
    
    // Check if empty after cleaning daughters
    if (dir.listSync().isEmpty && dir.path != 'lib') {
      stdout.writeln('Removing empty directory: ${dir.path}');
      dir.deleteSync();
      removed++;
    }
  }

  cleanTree(dir);
  stdout.writeln('Removed $removed empty folders.');
}
