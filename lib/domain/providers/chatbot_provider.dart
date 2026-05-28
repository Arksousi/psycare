// chatbot_provider.dart
// Riverpod providers for the AI chatbot feature.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/chatbot_service.dart';
import '../../data/models/chat_session_model.dart';

// ── Service provider ──────────────────────────────────────────────────────────

final chatbotServiceProvider = Provider<ChatbotService>(
  (_) => ChatbotService.instance,
);

// ── Messages stream ───────────────────────────────────────────────────────────

final chatMessagesProvider =
    StreamProvider.autoDispose.family<List<ChatMessageModel>, String>(
  (ref, sessionId) =>
      ref.read(chatbotServiceProvider).getMessages(sessionId),
);

// ── Active session stream ─────────────────────────────────────────────────────

final activeChatSessionProvider =
    StreamProvider.autoDispose.family<ChatSessionModel?, String>(
  (ref, sessionId) =>
      ref.read(chatbotServiceProvider).watchSession(sessionId),
);
