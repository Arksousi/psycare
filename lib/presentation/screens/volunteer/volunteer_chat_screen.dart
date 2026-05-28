import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/crisis_detection_service.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/chat_provider.dart';
import '../../../domain/providers/volunteer_provider.dart';
import '../../widgets/common/crisis_banner.dart';

class VolunteerChatScreen extends ConsumerStatefulWidget {
  const VolunteerChatScreen({super.key});

  @override
  ConsumerState<VolunteerChatScreen> createState() =>
      _VolunteerChatScreenState();
}

class _VolunteerChatScreenState
    extends ConsumerState<VolunteerChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  late String _sessionId;
  late String _volunteerId;
  late String _connectionId;
  late bool _isVolunteer;

  bool _crisisDetected = false;
  DateTime? _lastCrisisCheck;
  int _messagesSinceLastHourIncrement = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      _sessionId = '';
      _volunteerId = '';
      _connectionId = '';
      _isVolunteer = false;
      return;
    }
    _sessionId = args['sessionId'] as String? ?? '';
    _volunteerId = args['volunteerId'] as String? ?? '';
    _connectionId = args['connectionId'] as String? ?? '';
    _isVolunteer = args['isVolunteer'] as bool? ?? false;
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty || _sessionId.isEmpty) return;
    final user = ref.read(currentUserProvider);
    final senderRole = _isVolunteer ? 'volunteer' : 'patient';
    _textController.clear();

    ref.read(chatRepositoryProvider).sendMessage(
          sessionId: _sessionId,
          senderId: user?.uid ?? '',
          senderRole: senderRole,
          text: text,
        );

    _scrollToBottom();
    _checkCrisis(text, user?.uid ?? '');
    _trackHours();
  }

  Future<void> _checkCrisis(String text, String senderId) async {
    if (_isVolunteer) return; // only check patient messages
    if (_crisisDetected) return;
    if (text.length <= 10) return;
    final now = DateTime.now();
    if (_lastCrisisCheck != null &&
        now.difference(_lastCrisisCheck!) < const Duration(seconds: 3)) {
      return;
    }
    _lastCrisisCheck = now;

    final detected =
        await CrisisDetectionService.instance.isCrisis(text);
    if (!detected) return;

    if (mounted) setState(() => _crisisDetected = true);

    // Persist alert for therapist
    final volSnap = await FirebaseFirestore.instance
        .collection('volunteers')
        .doc(_volunteerId)
        .get();
    final volunteerName =
        volSnap.data()?['name'] as String? ?? 'Volunteer';

    final patSnap = await FirebaseFirestore.instance
        .collection('patients')
        .doc(senderId)
        .get();
    final therapistId =
        patSnap.data()?['therapistId'] as String? ?? '';

    if (therapistId.isEmpty) return;

    // Collect last 4 messages as context
    final msgSnap = await FirebaseFirestore.instance
        .collection('chat_sessions')
        .doc(_sessionId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(4)
        .get();
    final recent = msgSnap.docs
        .map((d) => d.data()['text'] as String? ?? '')
        .toList()
        .reversed
        .toList();

    await ref.read(volunteerServiceProvider).writeRedFlagAlert(
          sessionId: _sessionId,
          volunteerId: _volunteerId,
          volunteerName: volunteerName,
          therapistId: therapistId,
          patientId: senderId,
          flaggedMessage: text,
          recentMessages: recent,
        );
  }

  void _trackHours() {
    _messagesSinceLastHourIncrement++;
    if (_messagesSinceLastHourIncrement >= 10) {
      _messagesSinceLastHourIncrement = 0;
      ref
          .read(volunteerServiceProvider)
          .incrementVolunteerHours(_volunteerId);
    }
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

  Future<void> _showMeetupSheet() async {
    final placeCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('suggestMeetup'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: placeCtrl,
              decoration: InputDecoration(
                hintText: context.tr('meetupPlaceHint'),
                hintStyle: const TextStyle(color: AppColors.textHint),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: context.tr('meetupNoteHint'),
                hintStyle: const TextStyle(color: AppColors.textHint),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final place = placeCtrl.text.trim();
                  if (place.isEmpty) return;
                  Navigator.pop(ctx);
                  await _sendMeetupSuggestion(
                      place, noteCtrl.text.trim());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(context.tr('sendSuggestion'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
    placeCtrl.dispose();
    noteCtrl.dispose();
  }

  Future<void> _sendMeetupSuggestion(
      String place, String note) async {
    final user = ref.read(currentUserProvider);
    final patSnap = await FirebaseFirestore.instance
        .collection('volunteerConnections')
        .doc(_connectionId)
        .get();
    final patientId = patSnap.data()?['patientId'] as String? ?? '';

    final suggestionId =
        await ref.read(volunteerServiceProvider).createMeetupSuggestion(
              connectionId: _connectionId,
              volunteerId: _volunteerId,
              patientId: patientId,
              place: place,
              note: note,
            );

    await ref.read(chatRepositoryProvider).sendMessage(
          sessionId: _sessionId,
          senderId: user?.uid ?? '',
          senderRole: 'volunteer',
          text:
              '📅 meetup:$suggestionId|$place|$note',
        );
    _scrollToBottom();
  }

  Future<void> _confirmEndConnection() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(context.tr('endConnection')),
        content: Text(context.tr('endConnectionConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('endConnection'),
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final connSnap = await FirebaseFirestore.instance
        .collection('volunteerConnections')
        .doc(_connectionId)
        .get();
    final patientId =
        connSnap.data()?['patientId'] as String? ?? '';

    await ref.read(volunteerServiceProvider).endConnection(
          connectionId: _connectionId,
          volunteerId: _volunteerId,
          patientId: patientId,
          chatId: _sessionId,
        );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final messagesAsync =
        ref.watch(chatMessagesProvider(_sessionId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isVolunteer
                  ? context.tr('chatWithPatient')
                  : context.tr('chatWithVolunteer'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textSecondary),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'end') _confirmEndConnection();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'end',
                child: Row(
                  children: [
                    const Icon(Icons.close_rounded,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Text(context.tr('endConnection'),
                        style: const TextStyle(
                            color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Column(
          children: [
            // Crisis banner
            if (_crisisDetected)
              CrisisBanner(onDismiss: () => setState(() => _crisisDetected = false))
                  .animate()
                  .fadeIn()
                  .slideY(begin: -0.2, end: 0),

            // Messages
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        context.tr('noMessagesYet'),
                        style: const TextStyle(
                            color: AppColors.textHint, fontSize: 14),
                      ),
                    );
                  }
                  WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _scrollToBottom());
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final msg = messages[i];
                      return _buildMessageBubble(
                          msg, user?.uid ?? '');
                    },
                  );
                },
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary)),
                error: (e, _) => Center(child: Text(e.toString())),
              ),
            ),

            // Input bar
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              color: AppColors.surface,
              child: Row(
                children: [
                  if (_isVolunteer)
                    IconButton(
                      icon: const Text('📅',
                          style: TextStyle(fontSize: 22)),
                      onPressed: _showMeetupSheet,
                      tooltip: context.tr('suggestMeetup'),
                    ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: context.tr('typeMessage'),
                        hintStyle: const TextStyle(
                            color: AppColors.textHint, fontSize: 14),
                        filled: true,
                        fillColor: AppColors.cardBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, String myUid) {
    // Meetup message
    if (msg.text.startsWith('📅 meetup:')) {
      return _MeetupBubble(
        rawText: msg.text,
        myUid: myUid,
        isVolunteer: _isVolunteer,
      );
    }

    final isMe = msg.senderId == myUid;
    final isSystem = msg.senderRole == 'system';

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            msg.text,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
                fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
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
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 14,
                  color: isMe ? Colors.white : AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _MeetupBubble extends ConsumerWidget {
  final String rawText;
  final String myUid;
  final bool isVolunteer;

  const _MeetupBubble({
    required this.rawText,
    required this.myUid,
    required this.isVolunteer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Format: '📅 meetup:{suggestionId}|{place}|{note}'
    final payload = rawText.replaceFirst('📅 meetup:', '');
    final parts = payload.split('|');
    final suggestionId = parts.isNotEmpty ? parts[0] : '';
    final place = parts.length > 1 ? parts[1] : '';
    final note = parts.length > 2 ? parts[2] : '';

    final suggestionAsync = suggestionId.isNotEmpty
        ? ref
            .watch(volunteerServiceProvider)
            .watchMeetupSuggestion(suggestionId)
        : Stream.value(null);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Center(
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: suggestionAsync,
          builder: (ctx, snap) {
            final status =
                snap.data?['status'] as String? ?? 'pending';
            return Container(
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.of(context).size.width * 0.82,
              ),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('📅',
                          style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('meetupSuggestion'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _row(context.tr('meetupPlace'), place),
                  if (note.isNotEmpty)
                    _row(context.tr('meetupNote'), note),
                  const SizedBox(height: 12),
                  if (status == 'pending' && !isVolunteer) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => ref
                                .read(volunteerServiceProvider)
                                .updateMeetupStatus(
                                    suggestionId, 'agreed'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.success,
                              side: const BorderSide(
                                  color: AppColors.success),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                            ),
                            child: const Text('✅ Sounds good!'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => ref
                                .read(volunteerServiceProvider)
                                .updateMeetupStatus(
                                    suggestionId, 'declined'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(
                                  color: AppColors.error),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                            ),
                            child: const Text('❌ Maybe another time'),
                          ),
                        ),
                      ],
                    ),
                  ] else if (status == 'agreed') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        context.tr('meetupAgreed'),
                        style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ] else if (status == 'declined') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.textHint.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        context.tr('meetupDeclined'),
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ] else if (status == 'pending' && isVolunteer) ...[
                    Text(
                      context.tr('awaitingResponse'),
                      style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 12,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary),
            children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              TextSpan(text: value),
            ],
          ),
        ),
      );
}
