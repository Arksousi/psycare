// chat_sessions_screen.dart
// Shows all past and active immediate chat sessions for the current user.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/chat_provider.dart'
    show
        activeImmediateSessionsForTherapistProvider,
        directSessionsForTherapistProvider,
        patientSessionsProvider;

class ChatSessionsScreen extends ConsumerWidget {
  const ChatSessionsScreen({super.key});

  Future<bool?> _confirmDeleteAll(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete all conversations?'),
        content: const Text(
            'This will remove all chat history from your side. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final uid = user?.uid ?? '';
    final isTherapist = (user?.role ?? '') == 'therapist';
    final role = isTherapist ? 'therapist' : 'patient';

    final sessionsAsync = isTherapist
        ? ref.watch(directSessionsForTherapistProvider(uid))
        : ref.watch(patientSessionsProvider(uid));

    final activeImmediateAsync = isTherapist
        ? ref.watch(activeImmediateSessionsForTherapistProvider(uid))
        : const AsyncData(<ChatSession>[]);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_rounded,
                          color: AppColors.textPrimary, size: 20),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('myMessages'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            context.tr('myMessagesSubtitle'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    // Delete All button — only shown when there are sessions
                    sessionsAsync.maybeWhen(
                      data: (sessions) => sessions.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              tooltip: 'Delete all',
                              icon: const Icon(Icons.delete_sweep_rounded,
                                  color: AppColors.error),
                              onPressed: () async {
                                final confirmed =
                                    await _confirmDeleteAll(context);
                                if (confirmed == true && context.mounted) {
                                  await ref
                                      .read(chatRepositoryProvider)
                                      .deleteAllSessionsForUser(
                                          userId: uid, role: role);
                                }
                              },
                            ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: 16),

              Expanded(
                child: sessionsAsync.when(
                  data: (allSessions) {
                    final List<ChatSession> directList;
                    final List<ChatSession> immediateList;

                    if (isTherapist) {
                      directList = allSessions;
                      immediateList = activeImmediateAsync.maybeWhen(
                        data: (list) => list,
                        orElse: () => <ChatSession>[],
                      );
                    } else {
                      directList = allSessions
                          .where((s) => s.type == 'direct')
                          .toList();
                      immediateList = allSessions
                          .where((s) => s.type == 'immediate')
                          .toList();
                    }

                    final hasContent =
                        directList.isNotEmpty || immediateList.isNotEmpty;

                    if (!hasContent) {
                      return _EmptyState().animate().fadeIn(delay: 200.ms);
                    }

                    // Build flat item list: [header?, ...immediates, header?, ...directs]
                    final items = <_ListItem>[];
                    if (immediateList.isNotEmpty) {
                      items.add(_HeaderItem(isTherapist
                          ? 'Active Immediate Chat'
                          : 'Immediate Chat History'));
                      for (final s in immediateList) {
                        items.add(_SessionItem(s,
                            dismissible: !isTherapist));
                      }
                    }
                    if (directList.isNotEmpty) {
                      items.add(_HeaderItem(isTherapist
                          ? 'Direct Messages'
                          : 'Messages with Your Therapist'));
                      for (final s in directList) {
                        items.add(_SessionItem(s, dismissible: true));
                      }
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, i) {
                        if (items[i] is _HeaderItem) return const SizedBox(height: 8);
                        if (i + 1 < items.length && items[i + 1] is _HeaderItem) {
                          return const SizedBox(height: 20);
                        }
                        return const SizedBox(height: 12);
                      },
                      itemBuilder: (_, i) {
                        final item = items[i];
                        if (item is _HeaderItem) {
                          return Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          );
                        }
                        final si = item as _SessionItem;
                        final session = si.session;
                        final card = _SessionCard(
                          session: session,
                          isTherapist: isTherapist,
                          index: i,
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.chat,
                            arguments: <String, dynamic>{
                              'sessionId': session.id,
                              'therapistId': session.therapistId,
                            },
                          ),
                        );
                        if (!si.dismissible) return card;
                        return Dismissible(
                          key: ValueKey(session.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_rounded,
                                color: AppColors.error, size: 26),
                          ),
                          confirmDismiss: (_) => showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: const Text('Delete this conversation?'),
                              content: const Text(
                                  'This will remove it from your side only.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete',
                                      style:
                                          TextStyle(color: AppColors.error)),
                                ),
                              ],
                            ),
                          ),
                          onDismissed: (_) {
                            ref
                                .read(chatRepositoryProvider)
                                .deleteSessionForUser(
                                    sessionId: session.id, role: role);
                          },
                          child: card,
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (e, _) => Center(
                    child: Text(e.toString(),
                        style: const TextStyle(
                            color: AppColors.textSecondary)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

sealed class _ListItem {
  const _ListItem();
}

class _HeaderItem extends _ListItem {
  final String title;
  const _HeaderItem(this.title);
}

class _SessionItem extends _ListItem {
  final ChatSession session;
  final bool dismissible;
  const _SessionItem(this.session, {required this.dismissible});
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('noSessions'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('noSessionsBody'),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final ChatSession session;
  final bool isTherapist;
  final int index;
  final VoidCallback onTap;

  const _SessionCard({
    required this.session,
    required this.isTherapist,
    required this.index,
    required this.onTap,
  });

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isActive = session.status == 'active';
    final statusColor = isActive ? AppColors.success : AppColors.textHint;
    final preview = session.patientSummary.isNotEmpty
        ? session.patientSummary
        : context.tr('noSummaryAvailable');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? AppColors.success.withValues(alpha: 0.35)
                : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTherapist
                            ? context.tr('patientSession')
                            : session.type == 'immediate'
                                ? 'Immediate Session'
                                : context.tr('therapistSession'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _formatDate(session.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive
                        ? context.tr('sessionActive')
                        : context.tr('sessionEnded'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                preview.length > 100
                    ? '${preview.substring(0, 100)}...'
                    : preview,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onTap,
                icon: Icon(
                  isActive
                      ? Icons.chat_bubble_rounded
                      : Icons.visibility_rounded,
                  size: 16,
                ),
                label: Text(
                  isActive
                      ? context.tr('resumeSession')
                      : context.tr('viewSession'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      isActive ? AppColors.primary : AppColors.textSecondary,
                  side: BorderSide(
                    color: isActive
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.border,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (index * 60).ms, duration: 300.ms)
        .slideY(begin: 0.06, end: 0);
  }
}
