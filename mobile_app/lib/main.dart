import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'chat_screen.dart';
import 'memory_manager.dart';
import 'project_manager.dart';

void main() {
  runApp(const MinMinApp());
}

class MinMinApp extends StatelessWidget {
  const MinMinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProjectManager()),
        ChangeNotifierProvider(create: (_) => MemoryManager()),
      ],
      child: MaterialApp(
        title: 'MIN MIN',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF124559),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF3EFE8),
          useMaterial3: true,
        ),
        home: const ChatScreen(),
      ),
    );
  }
}
