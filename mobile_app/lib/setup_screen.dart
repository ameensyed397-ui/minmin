import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ai_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  bool _isPicking = false;
  bool _isExtracting = false;
  String _statusText = '';

  Future<void> _pickModel() async {
    setState(() {
      _isPicking = true;
      _isExtracting = false;
      _statusText = 'Opening file picker…';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        dialogTitle: 'Select Gemma model (.task, .bin, or .zip)',
      );

      if (!mounted) return;

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isPicking = false;
          _statusText = '';
        });
        return;
      }

      final path = result.files.single.path;
      if (path == null) {
        _showError(
          'Could not access the file path.\n'
          'Try moving the file to your internal Downloads folder and selecting it again.',
        );
        setState(() {
          _isPicking = false;
          _statusText = '';
        });
        return;
      }

      final lower = path.toLowerCase();

      if (lower.endsWith('.zip')) {
        setState(() {
          _isPicking = false;
          _isExtracting = true;
          _statusText = 'Extracting .task file from zip…\nThis may take several minutes.';
        });
        await _handleZip(path);
      } else if (lower.endsWith('.task') || lower.endsWith('.bin')) {
        setState(() {
          _isPicking = false;
          _statusText = 'Loading model…';
        });
        if (mounted) await context.read<AiService>().loadModel(path);
      } else {
        _showError('Please select a .task, .bin, or .zip file.');
        setState(() {
          _isPicking = false;
          _statusText = '';
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('File picker error: $e');
        setState(() {
          _isPicking = false;
          _isExtracting = false;
          _statusText = '';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
          _isExtracting = false;
        });
      }
    }
  }

  Future<void> _handleZip(String zipPath) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final outPath = await compute(
        _extractTaskFromZip,
        {'zipPath': zipPath, 'destDir': docsDir.path},
      );

      if (!mounted) return;

      if (outPath == null) {
        _showError('No .task or .bin file found inside the zip.');
        return;
      }

      setState(() => _statusText = 'Loading model into AI engine…');
      await context.read<AiService>().loadModel(outPath);
    } catch (e) {
      if (mounted) _showError('Extraction failed: $e');
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _openKaggle() async {
    final uri = Uri.parse(
      'https://www.kaggle.com/models/google/gemma/frameworks/tfLite/variations/2b-it-cpu-int4',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiService>();
    final isModelLoading = ai.status == ModelStatus.loading;
    final isBusy = isModelLoading || _isPicking || _isExtracting;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A15),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0A1E), Color(0xFF0A0A15)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // ── Hero ──────────────────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF7C5CBF).withValues(alpha: 0.3),
                                  const Color(0xFF7C5CBF).withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF9D7FD4), Color(0xFF4C2A8C)],
                              ),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7C5CBF)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.psychology_outlined,
                                color: Colors.white, size: 38),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'MIN MIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Offline AI Coding Assistant',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 44),

                // ── Setup title ───────────────────────────────────────────
                const Text(
                  'One-time setup',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'MIN MIN runs entirely on your phone — no internet required after setup. '
                  'Download the AI model once (~1.5 GB), then select it below.',
                  style: TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 13.5, height: 1.55),
                ),

                const SizedBox(height: 28),

                // ── Steps ─────────────────────────────────────────────────
                _StepCard(
                  number: 1,
                  title: 'Download the AI model',
                  description:
                      'Open Kaggle, sign in with Google, accept the Gemma license, '
                      'then tap the download button. You will get a .zip or .task file (~1.5 GB).',
                  action: FilledButton.icon(
                    onPressed: _openKaggle,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1832),
                      foregroundColor: const Color(0xFF9D7FD4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(
                            color: Color(0xFF4A3575), width: 1),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 15),
                    label: const Text('Open Kaggle',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 12),

                _StepCard(
                  number: 2,
                  title: 'Select the downloaded file',
                  description:
                      'Tap the button below and pick the .zip or .task file from your '
                      'Downloads folder. If you downloaded a .zip, the app will extract it automatically.',
                  action: null,
                ),

                const SizedBox(height: 32),

                // ── Error banner ──────────────────────────────────────────
                if (ai.status == ModelStatus.error)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.red.shade800.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.redAccent, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ai.errorMessage,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Progress banner ───────────────────────────────────────
                if (isBusy)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161626),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2A2A45)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            backgroundColor: Color(0xFF1E1E3F),
                            color: Color(0xFF7C5CBF),
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.memory_outlined,
                                color: Color(0xFF7C5CBF), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _statusText.isNotEmpty
                                    ? _statusText
                                    : 'Loading model… this takes 10–30 seconds',
                                style: const TextStyle(
                                    color: Color(0xFF9CA3AF), fontSize: 13, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // ── CTA button ────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: isBusy
                        ? null
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFA07DE0), Color(0xFF5C3A9B)],
                          ),
                    color: isBusy ? const Color(0xFF1A1A2E) : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: isBusy
                        ? null
                        : [
                            BoxShadow(
                              color: const Color(0xFF7C5CBF)
                                  .withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isBusy ? null : _pickModel,
                      borderRadius: BorderRadius.circular(14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isExtracting
                                ? Icons.archive_outlined
                                : Icons.folder_open_outlined,
                            color: isBusy
                                ? const Color(0xFF9CA3AF)
                                : Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isExtracting
                                ? 'Extracting…'
                                : _isPicking
                                    ? 'Opening picker…'
                                    : 'Select Model File (.task or .zip)',
                            style: TextStyle(
                              color: isBusy
                                  ? const Color(0xFF9CA3AF)
                                  : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Footer note ───────────────────────────────────────────
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161626),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline,
                            color: Color(0xFF6B7280), size: 13),
                        SizedBox(width: 6),
                        Text(
                          'Model runs 100% offline — no data leaves your device',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.description,
    required this.action,
  });

  final int number;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F1F35), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF9D7FD4), Color(0xFF5C3A9B)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C5CBF).withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 12.5, height: 1.5),
                ),
                if (action != null) ...[const SizedBox(height: 10), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top-level function — runs in a separate isolate via compute() ────────────
// Extracts the first .task or .bin file from a zip into destDir.
// Returns the output file path, or null if no matching file was found.
String? _extractTaskFromZip(Map<String, String> args) {
  final zipPath = args['zipPath']!;
  final destDir = args['destDir']!;

  final inputStream = InputFileStream(zipPath);
  final archive = ZipDecoder().decodeBuffer(inputStream);

  for (final file in archive.files) {
    if (!file.isFile) continue;
    final name = file.name.split('/').last;
    if (name.endsWith('.task') || name.endsWith('.bin')) {
      final outPath = '$destDir/$name';
      // Re-use if already extracted (e.g. user taps again after a crash)
      if (!File(outPath).existsSync()) {
        final outStream = OutputFileStream(outPath);
        file.writeContent(outStream);
        outStream.close();
      }
      inputStream.close();
      return outPath;
    }
  }
  inputStream.close();
  return null;
}
