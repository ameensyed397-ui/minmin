import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'ai_service.dart';
import 'code_viewer.dart';
import 'project_manager.dart';

// ─── Colour palette ────────────────────────────────────────────────────────────
const _bg = Color(0xFF0A0A15);
const _surface = Color(0xFF0F0F1C);
const _card = Color(0xFF161626);
const _accent = Color(0xFF7C5CBF);
const _accentLight = Color(0xFF9D7FD4);
const _textPrimary = Color(0xFFE2E8F0);
const _textSecondary = Color(0xFF9CA3AF);
const _aiBubble = Color(0xFF161626);
const _divider = Color(0xFF1F2937);

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _promptCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  final List<ChatMessage> _messages = [];
  bool _generating = false;
  bool _inputFocused = false;
  String _attachedCode = '';
  String _attachedFileName = '';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _inputFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _promptCtrl.text.trim();
    if (text.isEmpty || _generating) return;

    String userMessage = text;
    if (_attachedCode.isNotEmpty) {
      userMessage =
          '$text\n\n```$_attachedFileName\n$_attachedCode\n```';
    }

    setState(() {
      _messages.add(ChatMessage(content: userMessage, isUser: true));
      _messages.add(ChatMessage(content: '', isUser: false, isStreaming: true));
      _generating = true;
      _promptCtrl.clear();
      _attachedCode = '';
      _attachedFileName = '';
    });
    _scrollToBottom();

    final ai = context.read<AiService>();
    final history = _messages.sublist(0, _messages.length - 1);

    try {
      final stream = ai.chat(history, userMessage);
      final sb = StringBuffer();
      await for (final token in stream) {
        sb.write(token);
        setState(() {
          _messages[_messages.length - 1] =
              _messages.last.copyWith(content: sb.toString());
        });
        _scrollToBottom();
      }
      setState(() {
        _messages[_messages.length - 1] =
            _messages.last.copyWith(isStreaming: false);
      });
    } catch (e) {
      setState(() {
        _messages[_messages.length - 1] = ChatMessage(
          content: 'Error: $e',
          isUser: false,
        );
      });
    } finally {
      setState(() => _generating = false);
      _scrollToBottom();
    }
  }

  Future<void> _attachFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    try {
      final content = await File(path).readAsString();
      setState(() {
        _attachedCode = content;
        _attachedFileName = result.files.single.name;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file.')),
        );
      }
    }
  }

  void _clearAttachment() => setState(() {
        _attachedCode = '';
        _attachedFileName = '';
      });

  void _clearChat() => setState(() => _messages.clear());

  @override
  Widget build(BuildContext context) {
    final project = context.watch<ProjectManager>();

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(project),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputArea(),
        ],
      ),
      drawer: _buildDrawer(project),
    );
  }

  PreferredSizeWidget _buildAppBar(ProjectManager project) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          border: const Border(
            bottom: BorderSide(color: Color(0xFF1A1A30), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu, size: 22, color: _textSecondary),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              // Logo
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF9D7FD4), Color(0xFF5C3A9B)],
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.psychology_outlined,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MIN MIN',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (project.hasProject)
                      Text(
                        project.projectName,
                        style:
                            const TextStyle(color: _textSecondary, fontSize: 10),
                      ),
                  ],
                ),
              ),
              if (_generating)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: _accentLight,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'thinking…',
                        style:
                            TextStyle(color: _accentLight, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Clear chat',
                onPressed: _messages.isEmpty ? null : _clearChat,
                color: _textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(ProjectManager project) {
    return Drawer(
      backgroundColor: _surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF1A1A30), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF9D7FD4), Color(0xFF5C3A9B)],
                      ),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.psychology_outlined,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MIN MIN',
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'Offline AI',
                        style:
                            TextStyle(color: _textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _DrawerSection(title: 'PROJECT', children: [
              _DrawerTile(
                icon: Icons.folder_open_outlined,
                label: project.hasProject
                    ? project.projectName
                    : 'Open folder…',
                subtitle: project.hasProject ? project.projectPath : null,
                onTap: () async {
                  await project.pickFolder();
                  if (mounted) Navigator.pop(context);
                },
              ),
              if (project.hasProject)
                _DrawerTile(
                  icon: Icons.code_outlined,
                  label: 'Browse files',
                  onTap: () {
                    Navigator.pop(context);
                    _showFileBrowser(project);
                  },
                ),
            ]),
            const Divider(color: _divider, height: 24),
            _DrawerSection(title: 'MODEL', children: [
              Consumer<AiService>(
                builder: (_, ai, __) => _DrawerTile(
                  icon: Icons.memory_outlined,
                  label: ai.isReady
                      ? ai.modelPath.split(RegExp(r'[\\/]')).last
                      : 'No model loaded',
                  subtitle: ai.isReady ? 'Running on-device ✓' : null,
                  trailing: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: ai.isReady ? const Color(0xFF4ADE80) : const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (ai.isReady
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFFEF4444))
                              .withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showModelOptions(ai);
                  },
                ),
              ),
            ]),
            const Spacer(),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _accent.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, color: _accent, size: 14),
                  SizedBox(width: 8),
                  Text(
                    '100% offline · runs on-device',
                    style: TextStyle(color: _textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFileBrowser(ProjectManager project) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined, color: _accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      project.projectName,
                      style: const TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: _divider, height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: project.entries.length,
                itemBuilder: (_, i) {
                  final e = project.entries[i];
                  final name = e.path.split(RegExp(r'[\\/]')).last;
                  final isDir = e is Directory;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isDir
                          ? Icons.folder_outlined
                          : Icons.insert_drive_file_outlined,
                      color: isDir ? _accent : _textSecondary,
                      size: 18,
                    ),
                    title: Text(name,
                        style: const TextStyle(
                            color: _textPrimary, fontSize: 13)),
                    onTap: isDir
                        ? null
                        : () async {
                            await project.openFile(e.path);
                            if (mounted) {
                              Navigator.pop(context);
                              _showCodeViewer(project);
                            }
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCodeViewer(ProjectManager project) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.97,
        minChildSize: 0.5,
        expand: false,
        builder: (_, __) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.code, color: _accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      project.selectedFilePath
                          .split(RegExp(r'[\\/]'))
                          .last,
                      style: const TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      final name = project.selectedFilePath
                          .split(RegExp(r'[\\/]'))
                          .last;
                      setState(() {
                        _attachedCode = project.selectedFileContent;
                        _attachedFileName = name;
                      });
                    },
                    icon: const Icon(Icons.auto_fix_high_outlined,
                        size: 14, color: _accentLight),
                    label: const Text('Ask AI',
                        style:
                            TextStyle(color: _accentLight, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const Divider(color: _divider, height: 1),
            Expanded(
              child: CodeViewer(
                path: project.selectedFilePath,
                content: project.selectedFileContent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showModelOptions(AiService ai) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Model',
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.swap_horiz, color: _accent),
              title: const Text('Change model',
                  style: TextStyle(color: _textPrimary)),
              subtitle: const Text('Select a different .task / .zip file',
                  style: TextStyle(color: _textSecondary, fontSize: 12)),
              onTap: () async {
                Navigator.pop(context);
                await ai.clearModel();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _MessageBubble(message: _messages[i]),
    );
  }

  Widget _buildEmptyState() {
    const suggestions = [
      'Review my code for bugs',
      'Help me write a function',
      'Explain this code to me',
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing icon
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _accent.withValues(alpha: 0.25),
                        _accent.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _accent.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(Icons.psychology_outlined,
                      color: _accent, size: 34),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'How can I help you code today?',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask anything — code review, bugs, refactoring…',
              style: TextStyle(color: _textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: suggestions.map((s) {
                return GestureDetector(
                  onTap: () {
                    _promptCtrl.text = s;
                    _focusNode.requestFocus();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _accent.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      s,
                      style: const TextStyle(
                          color: _accentLight, fontSize: 12.5),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: const Border(
          top: BorderSide(color: Color(0xFF1A1A30), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_attachedCode.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _accent.withValues(alpha: 0.4), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.attach_file,
                      color: _accentLight, size: 14),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _attachedFileName,
                      style:
                          const TextStyle(color: _accentLight, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _clearAttachment,
                    child: const Icon(Icons.close,
                        color: _textSecondary, size: 14),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _InputIconButton(
                icon: Icons.attach_file_outlined,
                onTap: _generating ? null : _attachFile,
                tooltip: 'Attach code file',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _inputFocused
                          ? _accent.withValues(alpha: 0.6)
                          : _divider,
                      width: _inputFocused ? 1.5 : 1,
                    ),
                    boxShadow: _inputFocused
                        ? [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.12),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: TextField(
                    controller: _promptCtrl,
                    focusNode: _focusNode,
                    maxLines: 5,
                    minLines: 1,
                    style:
                        const TextStyle(color: _textPrimary, fontSize: 14),
                    cursorColor: _accent,
                    decoration: const InputDecoration(
                      hintText: 'Ask MIN MIN…',
                      hintStyle: TextStyle(
                          color: _textSecondary, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _generating ? null : _send,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: _generating
                        ? null
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFA07DE0), Color(0xFF5C3A9B)],
                          ),
                    color: _generating
                        ? _card
                        : null,
                    shape: BoxShape.circle,
                    border: _generating
                        ? Border.all(color: _divider)
                        : null,
                    boxShadow: _generating
                        ? null
                        : [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.45),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: Icon(
                    _generating ? Icons.hourglass_top_rounded : Icons.arrow_upward_rounded,
                    color: _generating ? _textSecondary : Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Message bubble ──────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, left: 48),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6B4EA8), Color(0xFF3D2566)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(5),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4C3575).withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: SelectableText(
              message.content,
              style: const TextStyle(
                  color: _textPrimary, fontSize: 14, height: 1.5),
            ),
          ),
        ),
      );
    }

    // AI message with avatar
    return Container(
      margin: const EdgeInsets.only(bottom: 16, right: 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7C5CBF), Color(0xFF3A2266)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.3),
                  blurRadius: 6,
                ),
              ],
            ),
            child: const Icon(Icons.psychology_outlined,
                color: Colors.white, size: 16),
          ),
          // Bubble
          Flexible(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: _aiBubble,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(5),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(
                        color: const Color(0xFF252535), width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 36, 10),
                    child: message.isStreaming && message.content.isEmpty
                        ? const _TypingIndicator()
                        : SelectableText(
                            message.content,
                            style: const TextStyle(
                              color: _textPrimary,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                  ),
                ),
                if (message.content.isNotEmpty && !message.isStreaming)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: message.content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.copy_outlined,
                            size: 14, color: _textSecondary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Typing indicator ────────────────────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final delay = i * 0.3;
          final t = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
          final bounce = (t < 0.5 ? t * 2 : 2 - t * 2).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Transform.translate(
              offset: Offset(0, -4 * bounce),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _accentLight.withValues(alpha: 0.4 + 0.6 * bounce),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
class _InputIconButton extends StatelessWidget {
  const _InputIconButton(
      {required this.icon, required this.onTap, required this.tooltip});
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _card,
            shape: BoxShape.circle,
            border: Border.all(color: _divider),
          ),
          child: Icon(icon,
              color: onTap == null
                  ? _textSecondary.withValues(alpha: 0.3)
                  : _textSecondary,
              size: 20),
        ),
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  const _DrawerSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(title,
              style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2)),
        ),
        ...children,
      ],
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: _accent, size: 20),
      title: Text(label,
          style: const TextStyle(color: _textPrimary, fontSize: 13),
          overflow: TextOverflow.ellipsis),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style:
                  const TextStyle(color: _textSecondary, fontSize: 11),
              overflow: TextOverflow.ellipsis)
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
