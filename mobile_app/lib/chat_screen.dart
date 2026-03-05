import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ai_service.dart';
import 'code_viewer.dart';
import 'file_browser.dart';
import 'memory_manager.dart';
import 'project_manager.dart';
import 'terminal_panel.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final AiService _service = const AiService();
  final TextEditingController _projectController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _backendController = TextEditingController(text: 'http://127.0.0.1:8787');
  final TextEditingController _terminalController = TextEditingController(text: 'pwd');

  bool _busy = false;
  List<String> _currentPlan = <String>[];
  String _selectedFilePath = '';
  String _selectedFileContent = '';
  String _terminalOutput = '';

  @override
  void dispose() {
    _projectController.dispose();
    _promptController.dispose();
    _backendController.dispose();
    _terminalController.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _loadProject() async {
    await _perform(() async {
      final project = context.read<ProjectManager>();
      final memory = context.read<MemoryManager>();
      project.setBackendUrl(_backendController.text.trim());
      final response = await _service.loadProject(
        backendUrl: project.backendUrl,
        projectPath: _projectController.text.trim(),
      );
      final files = (response['files'] as List<dynamic>).cast<String>();
      project.setProject(
        response['project_path'] as String,
        files,
        response['summary'] as String,
      );
      memory.addEntry('system', 'Loaded project ${response['project_path']}');
    });
  }

  Future<void> _createPlan() async {
    final project = context.read<ProjectManager>();
    if (project.projectPath.isEmpty) {
      return;
    }
    await _perform(() async {
      final memory = context.read<MemoryManager>();
      final response = await _service.createPlan(
        backendUrl: project.backendUrl,
        projectPath: project.projectPath,
        prompt: _promptController.text.trim(),
      );
      _currentPlan = (response['plan'] as List<dynamic>).cast<String>();
      memory.addEntry('user', _promptController.text.trim());
      memory.addEntry('assistant', _currentPlan.join('\n'));
    });
  }

  Future<void> _executePlan() async {
    final project = context.read<ProjectManager>();
    if (project.projectPath.isEmpty || _currentPlan.isEmpty) {
      return;
    }
    await _perform(() async {
      final memory = context.read<MemoryManager>();
      final response = await _service.executePlan(
        backendUrl: project.backendUrl,
        projectPath: project.projectPath,
        prompt: _promptController.text.trim(),
        approvedPlan: _currentPlan,
      );
      final result = response['result'] as Map<String, dynamic>;
      memory.addEntry('assistant', result['raw_response'] as String? ?? 'No model response.');
    });
  }

  Future<void> _openFile(String path) async {
    final project = context.read<ProjectManager>();
    await _perform(() async {
      final response = await _service.readFile(backendUrl: project.backendUrl, path: path);
      _selectedFilePath = response['path'] as String;
      _selectedFileContent = response['content'] as String;
    });
  }

  Future<void> _runTerminal() async {
    final project = context.read<ProjectManager>();
    if (project.projectPath.isEmpty) {
      return;
    }
    await _perform(() async {
      final response = await _service.runTerminal(
        backendUrl: project.backendUrl,
        projectPath: project.projectPath,
        command: _terminalController.text.trim(),
      );
      _terminalOutput = 'status: ${response['status']}\nstdout:\n${response['stdout'] ?? ''}\n\nstderr:\n${response['stderr'] ?? ''}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final project = context.watch<ProjectManager>();
    final memory = context.watch<MemoryManager>();
    final width = MediaQuery.of(context).size.width;
    final wide = width > 1100;
    final stackedControls = width < 760;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MIN MIN'),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildProjectBar(stackedControls),
          Expanded(
            child: wide ? _buildDesktop(project, memory) : _buildMobile(project, memory),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectBar(bool stackedControls) {
    final backendField = TextField(
      controller: _backendController,
      decoration: const InputDecoration(
        labelText: 'Backend URL',
        border: OutlineInputBorder(),
      ),
    );
    final projectField = TextField(
      controller: _projectController,
      decoration: const InputDecoration(
        labelText: 'Project path',
        border: OutlineInputBorder(),
      ),
    );
    final loadButton = FilledButton(
      onPressed: _busy ? null : _loadProject,
      child: const Text('Load Project'),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE2C391), Color(0xFFB8D8D8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: stackedControls
          ? Column(
              children: [
                backendField,
                const SizedBox(height: 12),
                projectField,
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: loadButton),
              ],
            )
          : Row(
              children: [
                Expanded(child: backendField),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: projectField),
                const SizedBox(width: 12),
                loadButton,
              ],
            ),
    );
  }

  Widget _buildDesktop(ProjectManager project, MemoryManager memory) {
    return Row(
      children: [
        SizedBox(
          width: 280,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FileBrowser(files: project.files, onSelected: _openFile),
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
            child: _buildChat(project, memory),
          ),
        ),
        SizedBox(
          width: 420,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
            child: CodeViewer(path: _selectedFilePath, content: _selectedFileContent),
          ),
        ),
      ],
    );
  }

  Widget _buildMobile(ProjectManager project, MemoryManager memory) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(tabs: [Tab(text: 'Chat'), Tab(text: 'Files'), Tab(text: 'Code')]),
          Expanded(
            child: TabBarView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildChat(project, memory),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: FileBrowser(files: project.files, onSelected: _openFile),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: CodeViewer(path: _selectedFilePath, content: _selectedFileContent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChat(ProjectManager project, MemoryManager memory) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    project.summary.isEmpty ? 'No project loaded.' : project.summary,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _promptController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Prompt',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _createPlan,
                      child: const Text('Create Plan'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _busy ? null : _executePlan,
                      child: const Text('Approve + Execute'),
                    ),
                  ],
                ),
                if (_currentPlan.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _currentPlan.map((step) => '▶ $step').join('\n'),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: memory.entries.length,
              itemBuilder: (context, index) {
                final entry = memory.entries[index];
                return Align(
                  alignment: entry.role == 'user' ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 680),
                    decoration: BoxDecoration(
                      color: entry.role == 'user' ? const Color(0xFF124559) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${entry.role.toUpperCase()}\n${entry.message}',
                      style: TextStyle(color: entry.role == 'user' ? Colors.white : Colors.black87),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: TerminalPanel(
            controller: _terminalController,
            output: _terminalOutput,
            onRun: _busy ? () {} : _runTerminal,
          ),
        ),
      ],
    );
  }
}
