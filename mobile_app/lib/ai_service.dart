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

  Future<bool> ping(String backendUrl) async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/health'),
        headers: const {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> loadProject({
    required String backendUrl,
    required String projectPath,
  }) async {
    final response = await http.post(
      Uri.parse('$backendUrl/api/projects/load'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'path': projectPath}),
    ).timeout(const Duration(seconds: 120));
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
    ).timeout(const Duration(seconds: 180));
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
    ).timeout(const Duration(seconds: 300));
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
    ).timeout(const Duration(seconds: 120));
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
    ).timeout(const Duration(seconds: 30));
    return _decode(response);
  }
}
