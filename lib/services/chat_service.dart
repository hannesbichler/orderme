import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import 'app_settings_service.dart';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final ValueNotifier<int> unreadCount = ValueNotifier(0);
  final List<ChatMessage> messages = [];

  final Set<String> _seenIds = {};
  DateTime? _lastFetched;
  Timer? _timer;
  bool _screenOpen = false;

  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
    _poll();
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  void onChatScreenOpened() {
    _screenOpen = true;
    unreadCount.value = 0;
  }

  void onChatScreenClosed() {
    _screenOpen = false;
  }

  Future<void> _poll() async {
    try {
      final since = _lastFetched;
      final uri = since == null
          ? Uri.parse('${AppSettingsService.baseUrl}/chat/messages')
          : Uri.parse(
              '${AppSettingsService.baseUrl}/chat/messages?since=${Uri.encodeComponent(since.toIso8601String())}');

      final res = await http.get(uri);
      if (res.statusCode != 200) return;

      final List<dynamic> data = json.decode(res.body) as List<dynamic>;
      final fetched = data
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .where((m) => _seenIds.add(m.id))
          .toList();

      if (fetched.isEmpty) return;

      messages.addAll(fetched);
      _lastFetched = fetched.last.timestamp;

      if (!_screenOpen) {
        unreadCount.value += fetched.length;
      }
    } catch (_) {}
  }

  Future<ChatMessage?> sendMessage(String sender, String text) async {
    try {
      final res = await http.post(
        Uri.parse('${AppSettingsService.baseUrl}/chat/messages'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'sender': sender, 'text': text}),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final msg = ChatMessage.fromJson(json.decode(res.body) as Map<String, dynamic>);
      _seenIds.add(msg.id);
      messages.add(msg);
      _lastFetched = msg.timestamp;
      return msg;
    } catch (_) {
      return null;
    }
  }
}
