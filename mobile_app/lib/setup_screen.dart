import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ai_service.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  Future<void> _pickModel(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      dialogTitle: 'Select Gemma .task model file',
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    if (!path.endsWith('.task') && !path.endsWith('.bin')) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a .task or .bin model file.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (context.mounted) {
      await context.read<AiService>().loadModel(path);
    }
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
    final isLoading = ai.status == ModelStatus.loading;

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
                      // Glowing icon
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
                  'You need to download the AI model file once (~1.5 GB).',
                  style: TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 13.5, height: 1.55),
                ),

                const SizedBox(height: 28),

                // ── Steps ─────────────────────────────────────────────────
                _StepCard(
                  number: 1,
                  title: 'Get the AI model',
                  description:
                      'Open Kaggle, sign in with Google, accept the Gemma '
                      'license, then download gemma-2b-it-cpu-int4.task (~1.5 GB) to your phone.',
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
                      'After downloading, tap the button below and select the '
                      '.task file from your Downloads folder.',
                  action: null,
                ),

                const SizedBox(height: 32),

                // ── Error ─────────────────────────────────────────────────
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

                // ── Loading ───────────────────────────────────────────────
                if (isLoading)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161626),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2A2A45)),
                    ),
                    child: Column(
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
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.memory_outlined,
                                color: Color(0xFF7C5CBF), size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Loading model… this takes 10–30 seconds',
                              style: TextStyle(
                                  color: Color(0xFF9CA3AF), fontSize: 13),
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
                    gradient: isLoading
                        ? null
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFA07DE0), Color(0xFF5C3A9B)],
                          ),
                    color: isLoading ? const Color(0xFF1A1A2E) : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: isLoading
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
                      onTap: isLoading ? null : () => _pickModel(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open_outlined,
                            color: isLoading
                                ? const Color(0xFF9CA3AF)
                                : Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Select Model File',
                            style: TextStyle(
                              color: isLoading
                                  ? const Color(0xFF9CA3AF)
                                  : Colors.white,
                              fontSize: 16,
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
          // Step number badge
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
