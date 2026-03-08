import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'ai_service.dart';
import 'code_viewer.dart';
import 'project_manager.dart';

// ─── Colour palette ────────────────────────────────────────────────────────────
const _bg = Color(0xFF0D0D1A);
const _surface = Color(0xFF13131F);
const _card = Color(0xFF1A1A2E);
const _accent = Color(0xFF7C5CBF);
const _accentLight = Color(0xFF9D7FD4);
const _textPrimary = Color(0xFFE2E8F0);
const _textSecondary = Color(0xFF9CA3AF);
const _userBubble = Color(0xFF4C3575);
const _aiBubble = Color(0xFF1E293B);
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
  String _attachedCode = '';
  String _attachedFileName = '';

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

  AppBar _buildAppBar(ProjectManager project) {
    return AppBar(
      backgroundColor: _surface,
      foregroundColor: _textPrimary,
      elevation: 0,
      centerTitle: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MIN MIN',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          if (project.hasProject)
            Text(
              project.projectName,
              style: const TextStyle(color: _textSecondary, fontSize: 11),
            ),
        ],
      ),
      actions: [
        if (_generating)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _accentLight,
                ),
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          tooltip: 'Clear chat',
          onPressed: _messages.isEmpty ? null : _clearChat,
          color: _textSecondary,
        ),
        Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, size: 22),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            color: _textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(ProjectManager project) {
    return Drawer(
      backgroundColor: _surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.psychology_outlined,
                        color: _accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'MIN MIN',
                    style: TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: _divider, height: 24),
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
                  trailing: Icon(
                    Icons.circle,
                    color: ai.isReady ? Colors.green : Colors.red,
                    size: 10,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showModelOptions(ai);
                  },
                ),
              ),
            ]),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                '100% offline · runs on-device',
                style: TextStyle(color: _textSecondary, fontSize: 11),
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
              subtitle: const Text('Select a different .task file',
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology_outlined,
                  color: _accent, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'How can I help you code today?',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask anything — code review, bugs, refactoring…',
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _MessageBubble(message: _messages[i]),
    );
  }

  Widget _buildInputArea() {
    return Container(
      color: _surface,
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
                color: _accent.withValues(alpha: 0.15),
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
                child: Container(
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _divider),
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
                          horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _generating ? null : _send,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _generating
                        ? _accent.withValues(alpha: 0.4)
                        : _accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _generating
                        ? Icons.hourglass_empty
                        : Icons.arrow_upward,
                    color: Colors.white,
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
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: isUser ? _userBubble : _aiBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 36, 10),
              child: message.isStreaming && message.content.isEmpty
                  ? const _TypingIndicator()
                  : SelectableText(
                      message.content,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
            ),
            if (!isUser &&
                message.content.isNotEmpty &&
                !message.isStreaming)
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
        vsync: this, duration: const Duration(milliseconds: 900))
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
          final t = (_ctrl.value * 3 - i).clamp(0.0, 1.0);
          final opacity = (t * 0.8 + 0.2).clamp(0.2, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Opacity(
              opacity: opacity,
              child: const CircleAvatar(
                  radius: 4, backgroundColor: _textSecondary),
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
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _card,
            shape: BoxShape.circle,
            border: Border.all(color: _divider),
          ),
          child: Icon(icon,
              color: onTap == null
                  ? _textSecondary.withValues(alpha: 0.4)
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
