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
  final TextEditingController _backendController =
      TextEditingController(text: 'http://192.168.1.x:8787');
  final TextEditingController _terminalController = TextEditingController(text: 'pwd');
  final ScrollController _chatScroll = ScrollController();

  bool _busy = false;
  bool? _connected; // null = untested, true = ok, false = failed
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
    _chatScroll.dispose();
    super.dispose();
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on Exception catch (error) {
      if (!mounted) return;
      final msg = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pingBackend() async {
    final url = _backendController.text.trim();
    setState(() => _connected = null);
    final ok = await _service.ping(url);
    if (!mounted) return;
    setState(() => _connected = ok);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Backend connected ✓' : 'Cannot reach backend at $url'),
        backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
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
      memory.addEntry('system', 'Loaded project ${response['project_path']} (${files.length} files)');
      _scrollChatToBottom();
    });
  }

  Future<void> _createPlan() async {
    final project = context.read<ProjectManager>();
    if (project.projectPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Load a project first.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (_promptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a prompt first.'), behavior: SnackBarBehavior.floating),
      );
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
      memory.addEntry('assistant', 'Plan:\n${_currentPlan.map((s) => '▶ $s').join('\n')}');
      _scrollChatToBottom();
    });
  }

  Future<void> _executePlan() async {
    final project = context.read<ProjectManager>();
    if (project.projectPath.isEmpty || _currentPlan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a plan first.'), behavior: SnackBarBehavior.floating),
      );
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
      final rawResponse = result['raw_response'] as String? ?? 'No model response.';
      final toolResults = result['tool_results'] as List<dynamic>? ?? [];
      final summary = StringBuffer(rawResponse);
      if (toolResults.isNotEmpty) {
        summary.write('\n\n--- Tool Results ---');
        for (final r in toolResults) {
          final t = r as Map<String, dynamic>;
          summary.write('\n[${t['tool']}] ${t['result']}');
        }
      }
      memory.addEntry('assistant', summary.toString());
      _currentPlan = [];
      _scrollChatToBottom();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Load a project first.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    await _perform(() async {
      final response = await _service.runTerminal(
        backendUrl: project.backendUrl,
        projectPath: project.projectPath,
        command: _terminalController.text.trim(),
      );
      _terminalOutput =
          'status: ${response['status'] ?? 'unknown'}\nstdout:\n${response['stdout'] ?? ''}\nstderr:\n${response['stderr'] ?? ''}';
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
          if (_connected != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                _connected! ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                color: _connected! ? Colors.green : Colors.red,
                size: 20,
              ),
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
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
    final connIcon = _connected == null
        ? Icons.wifi_find_outlined
        : _connected!
            ? Icons.wifi_outlined
            : Icons.wifi_off_outlined;
    final connColor = _connected == null
        ? Colors.grey
        : _connected!
            ? Colors.green
            : Colors.red;

    final backendField = TextField(
      controller: _backendController,
      onChanged: (_) => setState(() => _connected = null),
      decoration: InputDecoration(
        labelText: 'Backend URL',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: 'Test connection',
          onPressed: _busy ? null : _pingBackend,
          icon: Icon(connIcon, color: connColor, size: 20),
        ),
      ),
    );
    final projectField = TextField(
      controller: _projectController,
      decoration: const InputDecoration(
        labelText: 'Project path (on backend machine)',
        border: OutlineInputBorder(),
      ),
    );
    final loadButton = FilledButton.icon(
      onPressed: _busy ? null : _loadProject,
      icon: const Icon(Icons.folder_open_outlined, size: 18),
      label: const Text('Load'),
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
      length: 4,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.chat_outlined), text: 'Chat'),
              Tab(icon: Icon(Icons.folder_outlined), text: 'Files'),
              Tab(icon: Icon(Icons.code_outlined), text: 'Code'),
              Tab(icon: Icon(Icons.terminal_outlined), text: 'Terminal'),
            ],
            labelStyle: TextStyle(fontSize: 11),
            isScrollable: false,
          ),
          Expanded(
            child: TabBarView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildChatOnly(project, memory),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: FileBrowser(files: project.files, onSelected: _openFile),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: CodeViewer(path: _selectedFilePath, content: _selectedFileContent),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TerminalPanel(
                    controller: _terminalController,
                    output: _terminalOutput,
                    onRun: _busy ? () {} : _runTerminal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Mobile: chat + prompt controls only (no terminal panel embedded)
  Widget _buildChatOnly(ProjectManager project, MemoryManager memory) {
    return Column(
      children: [
        _buildPromptCard(project),
        const SizedBox(height: 12),
        Expanded(child: _buildMessageList(memory)),
      ],
    );
  }

  // Desktop: chat + prompt + terminal
  Widget _buildChat(ProjectManager project, MemoryManager memory) {
    return Column(
      children: [
        _buildPromptCard(project),
        const SizedBox(height: 12),
        Expanded(child: _buildMessageList(memory)),
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

  Widget _buildPromptCard(ProjectManager project) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (project.summary.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF124559).withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  project.summary,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Set Backend URL → Test → Load a project',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _promptController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Prompt',
                hintText: 'e.g. Add dark mode toggle to settings screen',
                border: const OutlineInputBorder(),
                suffixIcon: _promptController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _promptController.clear()),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _createPlan,
                  icon: const Icon(Icons.auto_fix_high_outlined, size: 16),
                  label: const Text('Plan'),
                ),
                OutlinedButton.icon(
                  onPressed: (_busy || _currentPlan.isEmpty) ? null : _executePlan,
                  icon: const Icon(Icons.play_arrow_outlined, size: 16),
                  label: const Text('Approve & Run'),
                ),
                if (_currentPlan.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() => _currentPlan = []),
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text('Clear plan'),
                  ),
              ],
            ),
            if (_currentPlan.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proposed Plan (${_currentPlan.length} steps)',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    ...(_currentPlan.asMap().entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '${e.key + 1}. ${e.value}',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(MemoryManager memory) {
    if (memory.entries.isEmpty) {
      return const Card(
        child: Center(
          child: Text('Chat history will appear here.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return Card(
      child: ListView.builder(
        controller: _chatScroll,
        padding: const EdgeInsets.all(12),
        itemCount: memory.entries.length,
        itemBuilder: (context, index) {
          final entry = memory.entries[index];
          final isUser = entry.role == 'user';
          final isSystem = entry.role == 'system';
          if (isSystem) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.message,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            );
          }
          return Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxWidth: 680),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF124559) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: SelectableText(
                entry.message,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
