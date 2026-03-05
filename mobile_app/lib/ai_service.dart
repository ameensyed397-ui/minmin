import 'dart:convert';

import 'package:http/http.dart' as http;

class AiService {
  const AiService();

  Map<String, dynamic> _decode(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final detail = (body is Map) ? (body['detail'] ?? response.body) : response.body;
      throw Exception('Server error ${response.statusCode}: $detail');
    }
    return body as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> loadProject({
    required String backendUrl,
    required String projectPath,
  }) async {
    final response = await http.post(
      Uri.parse('$backendUrl/api/projects/load'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'path': projectPath}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> createPlan({
    required String backendUrl,
    required String projectPath,
    required String prompt,
  }) async {
    final response = await http.post(
      Uri.parse('$backendUrl/api/chat/plan'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'project_path': projectPath, 'prompt': prompt}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> executePlan({
    required String backendUrl,
    required String projectPath,
    required String prompt,
    required List<String> approvedPlan,
  }) async {
    final response = await http.post(
      Uri.parse('$backendUrl/api/chat/execute'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'project_path': projectPath,
        'prompt': prompt,
        'approved_plan': approvedPlan,
      }),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> runTerminal({
    required String backendUrl,
    required String projectPath,
    required String command,
  }) async {
    final response = await http.post(
      Uri.parse('$backendUrl/api/terminal/run'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'project_path': projectPath, 'command': command}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> readFile({
    required String backendUrl,
    required String path,
  }) async {
    final response = await http.post(
      Uri.parse('$backendUrl/api/files/read'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'path': path}),
    );
    return _decode(response);
  }
}
