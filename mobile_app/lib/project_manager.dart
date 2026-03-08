import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class ProjectManager extends ChangeNotifier {
  String _projectPath = '';
  List<FileSystemEntity> _entries = [];
  String _selectedFilePath = '';
  String _selectedFileContent = '';

  String get projectPath => _projectPath;
  List<FileSystemEntity> get entries => _entries;
  bool get hasProject => _projectPath.isNotEmpty;
  String get selectedFilePath => _selectedFilePath;
  String get selectedFileContent => _selectedFileContent;
  String get projectName =>
      _projectPath.isEmpty ? '' : _projectPath.split(RegExp(r'[\\/]')).last;

  Future<void> pickFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select project folder',
    );
    if (result == null) return;
    _projectPath = result;
    _selectedFilePath = '';
    _selectedFileContent = '';
    await _scanDir(Directory(result));
    notifyListeners();
  }

  Future<void> _scanDir(Directory dir) async {
    try {
      final all = dir.listSync(recursive: false)
        ..sort((a, b) {
          if (a is Directory && b is File) return -1;
          if (a is File && b is Directory) return 1;
          return a.path.compareTo(b.path);
        });
      _entries = all
          .where((e) =>
              !_basename(e.path).startsWith('.') &&
              !const {'build', 'node_modules', '__pycache__', '.dart_tool'}
                  .contains(_basename(e.path)))
          .toList();
    } catch (_) {
      _entries = [];
    }
  }

  Future<void> openFile(String path) async {
    try {
      _selectedFilePath = path;
      _selectedFileContent = await File(path).readAsString();
    } catch (e) {
      _selectedFileContent = '// Could not read file: $e';
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedFilePath = '';
    _selectedFileContent = '';
    notifyListeners();
  }

  static String _basename(String path) =>
      path.split(RegExp(r'[\\/]')).last;
}
