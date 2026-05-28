import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../data/models/volunteer_connection_model.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/volunteer_provider.dart';

class MyConnectionsScreen extends ConsumerWidget {
  const MyConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider)?.uid ?? '';
    final connectionsAsync = ref.watch(volunteerConnectionsProvider(uid));

    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
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
                    Text(
                      context.tr('myConnections'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: 20),

              Expanded(
                child: connectionsAsync.when(
                  data: (connections) {
                    if (connections.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_outline_rounded,
                                color: AppColors.textHint, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              context.tr('noConnectionsYet'),
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms);
                    }

                    final active = connections
                        .where((c) => c.status == 'active')
                        .toList();
                    final ended = connections
                        .where((c) => c.status == 'ended')
                        .toList();

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      children: [
                        if (active.isNotEmpty) ...[
                          _sectionHeader(context.tr('activeConnections')),
                          const SizedBox(height: 8),
                          ...active.map((c) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 12),
                                child: _ConnectionCard(
                                    connection: c,
                                    volunteerId: uid),
                              )),
                        ],
                        if (ended.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _sectionHeader(context.tr('pastConnections')),
                          const SizedBox(height: 8),
                          ...ended.map((c) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 12),
                                child: _ConnectionCard(
                                    connection: c,
                                    volunteerId: uid,
                                    dimmed: true),
                              )),
                        ],
                      ],
                    );
                  },
                  loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary)),
                  error: (e, _) => Center(
                      child: Text(e.toString(),
                          style: const TextStyle(
                              color: AppColors.textSecondary))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      );
}

class _ConnectionCard extends StatelessWidget {
  final VolunteerConnectionModel connection;
  final String volunteerId;
  final bool dimmed;

  const _ConnectionCard({
    required this.connection,
    required this.volunteerId,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.55 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                connection.patientFirstName.isNotEmpty
                    ? connection.patientFirstName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connection.patientFirstName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  Text(
                    _formatDate(connection.connectedAt),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
            if (connection.isActive)
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.volunteerChat,
                  arguments: {
                    'sessionId': connection.chatId,
                    'volunteerId': volunteerId,
                    'connectionId': connection.connectionId,
                    'isVolunteer': true,
                  },
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                child: Text(context.tr('openChat')),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  context.tr('ended'),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textHint),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
