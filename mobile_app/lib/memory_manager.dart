import 'package:flutter/foundation.dart';

class ChatEntry {
  ChatEntry({
    required this.role,
    required this.message,
  });

  final String role;
  final String message;
}

class MemoryManager extends ChangeNotifier {
  final List<ChatEntry> _entries = <ChatEntry>[];

  List<ChatEntry> get entries => List<ChatEntry>.unmodifiable(_entries);

  void addEntry(String role, String message) {
    _entries.add(ChatEntry(role: role, message: message));
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
