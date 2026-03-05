import 'package:flutter/foundation.dart';

class ProjectManager extends ChangeNotifier {
  String backendUrl = 'http://127.0.0.1:8787';
  String projectPath = '';
  String summary = '';
  List<String> files = <String>[];

  void setBackendUrl(String value) {
    backendUrl = value;
    notifyListeners();
  }

  void setProject(String path, List<String> projectFiles, String projectSummary) {
    projectPath = path;
    files = projectFiles;
    summary = projectSummary;
    notifyListeners();
  }
}
