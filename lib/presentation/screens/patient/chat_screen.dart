// chat_screen.dart
// Real-time chat screen between patient and therapist.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/crisis_detection_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/therapist_model.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/chat_provider.dart';
import '../../widgets/common/crisis_banner.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _sessionId;
  late String _therapistId;
  late bool _readOnly;
  bool _sessionEndedHandled = false;
  bool _crisisDetected = false;
  DateTime? _lastCrisisCheck;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null || args['sessionId'] == null || args['therapistId'] == null) {
      // Missing route args — go back safely instead of crashing.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { Navigator.of(context).pop(); }
      });
      _sessionId = '';
      _therapistId = '';
      _readOnly = false;
      return;
    }
    _sessionId = args['sessionId'] as String;
    _therapistId = args['therapistId'] as String;
    _readOnly = args['readOnly'] == 'true';
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(currentUserProvider);
    final senderRole =
        (user?.role ?? '') == 'therapist' ? 'therapist' : 'patient';
    _textController.clear();
    ref.read(chatRepositoryProvider).sendMessage(
          sessionId: _sessionId,
          senderId: user?.uid ?? '',
          senderRole: senderRole,
          text: text,
        );
    _scrollToBottom();
    _checkCrisis(text);
  }

  Future<void> _checkCrisis(String text) async {
    if (_crisisDetected) return;
    if (text.length <= 10) return;
    final now = DateTime.now();
    if (_lastCrisisCheck != null &&
        now.difference(_lastCrisisCheck!) < const Duration(seconds: 3)) { return; }
    _lastCrisisCheck = now;
    final detected = await CrisisDetectionService.instance.isCrisis(text);
    if (detected && mounted) setState(() => _crisisDetected = true);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _endSession() {
    ref.read(chatRepositoryProvider).endSession(_sessionId);
  }

  Future<bool?> _confirmDelete(BuildContext ctx, {required bool all}) {
    return showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(all
            ? 'Delete all conversations?'
            : 'Delete this conversation?'),
        content: Text(all
            ? 'This will remove all your chat history. This cannot be undone.'
            : 'This will remove this conversation from your side. The other party will not be affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteSession(BuildContext ctx, dynamic user) async {
    final confirmed = await _confirmDelete(ctx, all: false);
    if (confirmed != true || !ctx.mounted) return;
    final role = (user?.role ?? '') == 'therapist' ? 'therapist' : 'patient';
    await ref.read(chatRepositoryProvider).deleteSessionForUser(
          sessionId: _sessionId,
          role: role,
        );
    if (ctx.mounted) Navigator.pop(ctx);
  }

  Future<void> _handleDeleteAll(BuildContext ctx, dynamic user) async {
    final confirmed = await _confirmDelete(ctx, all: true);
    if (confirmed != true || !ctx.mounted) return;
    final role = (user?.role ?? '') == 'therapist' ? 'therapist' : 'patient';
    await ref.read(chatRepositoryProvider).deleteAllSessionsForUser(
          userId: user?.uid ?? '',
          role: role,
        );
    if (ctx.mounted) Navigator.pop(ctx);
  }

  Future<void> _showPostSessionSheet() async {
    if (_sessionEndedHandled) return;
    _sessionEndedHandled = true;

    final snap = await FirebaseFirestore.instance
        .collection('therapists')
        .doc(_therapistId)
        .get();
    final data = snap.data();
    final therapistName = data?['name'] as String? ?? 'Your Therapist';
    final therapistModel =
        data != null ? TherapistModel.fromMap(_therapistId, data) : null;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PostSessionSheet(
        therapistName: therapistName,
        onBrowseProfile: therapistModel == null
            ? null
            : () {
                Navigator.pop(ctx);
                Navigator.pushNamed(
                  context,
                  AppRoutes.therapistProfile,
                  arguments: therapistModel,
                );
              },
        onDecline: () {
          Navigator.pop(ctx);
          ref.read(chatRepositoryProvider).deleteSessionForUser(
                sessionId: _sessionId,
                role: 'patient',
              );
          Navigator.pushNamedAndRemoveUntil(
              context, AppRoutes.patientDashboard, (_) => false);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(chatSessionProvider(_sessionId));
    final messagesAsync = ref.watch(chatMessagesProvider(_sessionId));
    final user = ref.watch(currentUserProvider);

    return sessionAsync.when(
      data: (session) {
        final isEnded = session?.status == 'ended';
        final isTherapist = (user?.role ?? '') == 'therapist';

        if (isEnded && session?.type == 'immediate') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (isTherapist && !_readOnly) {
              if (!_sessionEndedHandled) {
                _sessionEndedHandled = true;
                Navigator.pushNamedAndRemoveUntil(
                    context, AppRoutes.therapistDashboard, (_) => false);
              }
            } else if (!isTherapist) {
              _showPostSessionSheet();
            }
          });
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: AppColors.textPrimary, size: 20),
              onPressed: () {
                if (isTherapist && !_readOnly) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, AppRoutes.therapistDashboard, (_) => false);
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTherapist ? 'Patient Chat' : context.tr('yourTherapist'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  isEnded
                      ? context.tr('sessionEnded')
                      : context.tr('sessionActive'),
                  style: TextStyle(
                    fontSize: 12,
                    color: isEnded ? AppColors.error : AppColors.success,
                  ),
                ),
              ],
            ),
            actions: [
              if (!isEnded && !_readOnly)
                TextButton(
                  onPressed: _endSession,
                  child: Text(
                    context.tr('endSession'),
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              if (!_readOnly)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      color: AppColors.textPrimary),
                  onSelected: (value) {
                    if (value == 'delete_session') {
                      _handleDeleteSession(context, user);
                    } else if (value == 'delete_all') {
                      _handleDeleteAll(context, user);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete_session',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline,
                            color: AppColors.error),
                        title: Text('Delete this conversation'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete_all',
                      child: ListTile(
                        leading: Icon(Icons.delete_sweep_rounded,
                            color: AppColors.error),
                        title: Text('Delete all my conversations'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: Column(
            children: [
              if (isEnded) _EndedBanner(context: context),
              Expanded(
                child: messagesAsync.when(
                  data: (messages) {
                    if (messages.isNotEmpty) {
                      _scrollToBottom();
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (ctx, i) => _MessageBubble(
                        message: messages[i],
                        isMe: messages[i].senderId == user?.uid,
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(e.toString())),
                ),
              ),
              if (_crisisDetected)
                CrisisBanner(
                  onDismiss: () => setState(() => _crisisDetected = false),
                ),
              if (!isEnded && !_readOnly) _InputBar(
                controller: _textController,
                onSend: _sendMessage,
                hint: context.tr('typeMessage'),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text(e.toString())),
      ),
    );
  }
}

class _EndedBanner extends StatelessWidget {
  final BuildContext context;
  const _EndedBanner({required this.context});

  @override
  Widget build(BuildContext outerContext) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.error.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              outerContext.tr('sessionEnded'),
              style: const TextStyle(
                  color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (message.senderRole == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              message.text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isMe ? Colors.white : AppColors.textPrimary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0);
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final String hint;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                    color: AppColors.textHint, fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostSessionSheet extends StatelessWidget {
  final String therapistName;
  final VoidCallback? onBrowseProfile;
  final VoidCallback onDecline;

  const _PostSessionSheet({
    required this.therapistName,
    required this.onBrowseProfile,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 48),
          const SizedBox(height: 16),
          Text(
            context.tr('sessionEnded'),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Would you like to see Dr. $therapistName\'s profile and book them as your therapist?',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5),
          ),
          const SizedBox(height: 24),
          if (onBrowseProfile != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onBrowseProfile,
                icon: const Icon(Icons.person_search_rounded, size: 18),
                label: Text('Browse Dr. $therapistName\'s Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onDecline,
              child: const Text('No Thanks',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}
