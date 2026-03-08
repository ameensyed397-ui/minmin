import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ModelStatus { none, loading, ready, error }

class ChatMessage {
  const ChatMessage({
    required this.content,
    required this.isUser,
    this.isStreaming = false,
  });

  final String content;
  final bool isUser;
  final bool isStreaming;

  ChatMessage copyWith({String? content, bool? isStreaming}) => ChatMessage(
        content: content ?? this.content,
        isUser: isUser,
        isStreaming: isStreaming ?? this.isStreaming,
      );
}

class AiService extends ChangeNotifier {
  ModelStatus _status = ModelStatus.none;
  String _errorMessage = '';
  String _modelPath = '';

  ModelStatus get status => _status;
  String get errorMessage => _errorMessage;
  String get modelPath => _modelPath;
  bool get isReady => _status == ModelStatus.ready;

  static const _kModelPathKey = 'model_path';

  /// Called at app startup — loads model from saved path if it exists.
  Future<void> initFromSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kModelPathKey);
    if (saved != null && File(saved).existsSync()) {
      await loadModel(saved);
    }
  }

  Future<void> loadModel(String path) async {
    _status = ModelStatus.loading;
    _errorMessage = '';
    notifyListeners();
    try {
      // In flutter_gemma 0.2.x, init() takes the modelPath directly
      await FlutterGemmaPlugin.instance.init(
        modelPath: path,
        maxTokens: 1024,
        temperature: 0.8,
        topK: 40,
        randomSeed: 42,
      );
      _modelPath = path;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kModelPathKey, path);
      _status = ModelStatus.ready;
    } catch (e) {
      _status = ModelStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> clearModel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kModelPathKey);
    _modelPath = '';
    _status = ModelStatus.none;
    notifyListeners();
  }

  /// Returns a stream of token strings for the AI response.
  Stream<String> chat(List<ChatMessage> history, String newMessage) {
    if (!isReady) throw StateError('Model not loaded');
    final prompt = _buildPrompt(history, newMessage);
    return FlutterGemmaPlugin.instance
        .getResponseAsync(prompt: prompt)
        .where((token) => token != null)
        .cast<String>();
  }

  /// Gemma instruction-tuned chat format.
  String _buildPrompt(List<ChatMessage> history, String message) {
    const system =
        'You are MIN MIN, an expert offline AI coding assistant. '
        'Help the user with code review, debugging, refactoring, and software '
        'engineering questions. Be concise and precise.';
    final sb = StringBuffer(
      '<start_of_turn>system\n$system<end_of_turn>\n',
    );
    // Keep last 10 turns to stay within context window
    final recent =
        history.length > 10 ? history.sublist(history.length - 10) : history;
    for (final msg in recent) {
      final role = msg.isUser ? 'user' : 'model';
      sb.write('<start_of_turn>$role\n${msg.content}<end_of_turn>\n');
    }
    sb.write(
        '<start_of_turn>user\n$message<end_of_turn>\n<start_of_turn>model\n');
    return sb.toString();
  }
}
