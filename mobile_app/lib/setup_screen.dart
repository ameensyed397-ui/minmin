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

  Future<void> _openHuggingFace() async {
    // Gemma .task files (MediaPipe format) are hosted on Kaggle
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
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // Logo / title
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C5CBF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.psychology_outlined,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MIN MIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'Offline AI Coding Assistant',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 48),
              const Text(
                'One-time setup',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'MIN MIN runs entirely on your phone — no internet required after setup. '
                'You need to download the AI model file once (~1.5 GB).',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 36),
              _Step(
                number: '1',
                title: 'Get the AI model',
                description:
                    'Tap below to open Kaggle. Sign in with a Google account, '
                    'accept the Gemma license, then download '
                    'gemma-2b-it-cpu-int4.task (~1.5 GB) to your phone.',
                action: TextButton.icon(
                  onPressed: _openHuggingFace,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open Kaggle →'),
                ),
              ),
              const SizedBox(height: 20),
              _Step(
                number: '2',
                title: 'Select the downloaded file',
                description:
                    'After downloading, tap the button below and select the .task file '
                    'from your Downloads folder.',
                action: null,
              ),
              const SizedBox(height: 32),
              if (ai.status == ModelStatus.error)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade700),
                  ),
                  child: Text(
                    'Error: ${ai.errorMessage}',
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              if (isLoading)
                const Column(
                  children: [
                    LinearProgressIndicator(
                      backgroundColor: Color(0xFF1E1E3F),
                      color: Color(0xFF7C5CBF),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Loading model into memory… this takes 10–30s',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: isLoading ? null : () => _pickModel(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C5CBF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text(
                    'Select Model File',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                'The model runs 100% offline after setup. No data ever leaves your device.',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.description,
    required this.action,
  });

  final String number;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFF7C5CBF),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
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
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style:
                    const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, height: 1.4),
              ),
              if (action != null) ...[const SizedBox(height: 6), action!],
            ],
          ),
        ),
      ],
    );
  }
}
