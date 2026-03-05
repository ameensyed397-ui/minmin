import 'package:flutter/material.dart';

class TerminalPanel extends StatelessWidget {
  const TerminalPanel({
    super.key,
    required this.controller,
    required this.output,
    required this.onRun,
  });

  final TextEditingController controller;
  final String output;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Terminal command',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: onRun,
                  child: const Text('Run'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                output.isEmpty ? 'Terminal output appears here.' : output,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
