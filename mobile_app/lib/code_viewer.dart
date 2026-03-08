import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/github.dart';

const Map<String, String> _extToLang = {
  '.dart': 'dart',
  '.py': 'python',
  '.js': 'javascript',
  '.jsx': 'javascript',
  '.ts': 'typescript',
  '.tsx': 'tsx',
  '.json': 'json',
  '.yaml': 'yaml',
  '.yml': 'yaml',
  '.md': 'markdown',
  '.sh': 'bash',
  '.bash': 'bash',
  '.kt': 'kotlin',
  '.java': 'java',
  '.html': 'xml',
  '.xml': 'xml',
  '.css': 'css',
  '.scss': 'css',
  '.go': 'go',
  '.rs': 'rust',
  '.cpp': 'cpp',
  '.c': 'c',
  '.h': 'cpp',
  '.swift': 'swift',
  '.gradle': 'groovy',
  '.sql': 'sql',
  '.toml': 'ini',
};

String _detectLanguage(String path) {
  final dot = path.lastIndexOf('.');
  if (dot == -1) return 'plaintext';
  return _extToLang[path.substring(dot).toLowerCase()] ?? 'plaintext';
}

class CodeViewer extends StatefulWidget {
  const CodeViewer({
    super.key,
    required this.path,
    required this.content,
  });

  final String path;
  final String content;

  @override
  State<CodeViewer> createState() => _CodeViewerState();
}

class _CodeViewerState extends State<CodeViewer> {
  bool _darkMode = true;

  @override
  Widget build(BuildContext context) {
    final lang = _detectLanguage(widget.path);
    final theme = _darkMode ? atomOneDarkTheme : githubTheme;
    final bgColor = _darkMode ? const Color(0xFF282C34) : const Color(0xFFF8F8F8);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFF124559),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.path.isEmpty ? 'Code Preview' : widget.path.split(RegExp(r'[\\/]')).last,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.path.isNotEmpty)
                        Text(
                          lang.toUpperCase(),
                          style: const TextStyle(color: Color(0xFF9ECFD4), fontSize: 10),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _darkMode ? 'Light theme' : 'Dark theme',
                  onPressed: () => setState(() => _darkMode = !_darkMode),
                  icon: Icon(
                    _darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy',
                  onPressed: widget.content.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(ClipboardData(text: widget.content));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copied to clipboard.')),
                            );
                          }
                        },
                  icon: const Icon(Icons.copy_outlined, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.content.isEmpty
                ? const Center(
                    child: Text(
                      'Select a file to preview its contents.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : Container(
                    color: bgColor,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: HighlightView(
                          widget.content,
                          language: lang,
                          theme: theme,
                          padding: const EdgeInsets.all(16),
                          textStyle: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
