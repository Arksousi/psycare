import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../data/models/therapist_connection_model.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/therapist_provider.dart';

class TherapistConnectionRequestsScreen extends ConsumerWidget {
  const TherapistConnectionRequestsScreen({super.key});

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Future<void> _accept(
      BuildContext context, WidgetRef ref, TherapistConnectionModel conn) async {
    try {
      final sessionId = await ref
          .read(therapistConnectionServiceProvider)
          .acceptConnectionRequest(
            connectionId: conn.connectionId,
            patientId: conn.patientId,
            therapistId: conn.therapistId,
          );
      if (context.mounted) {
        Navigator.pushNamed(context, AppRoutes.chat, arguments: {
          'sessionId': sessionId,
          'therapistId': conn.therapistId,
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _decline(
      WidgetRef ref, String connectionId) async {
    await ref
        .read(therapistConnectionServiceProvider)
        .declineConnectionRequest(connectionId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final requestsAsync = ref.watch(
        therapistIncomingConnectionRequestsProvider(user?.uid ?? ''));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Connection Requests',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add_outlined,
                      size: 56, color: AppColors.textHint),
                  SizedBox(height: 12),
                  Text(
                    'No pending connection requests',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 15),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, i) {
              final conn = requests[i];
              return _RequestCard(
                initials: _initials(conn.patientName),
                patientName: conn.patientName,
                onAccept: () => _accept(context, ref, conn),
                onDecline: () => _decline(ref, conn.connectionId),
              )
                  .animate(delay: Duration(milliseconds: i * 70))
                  .fadeIn(duration: 280.ms)
                  .slideY(begin: 0.06, end: 0);
            },
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final String initials;
  final String patientName;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _RequestCard({
    required this.initials,
    required this.patientName,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              initials,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Wants to connect with you',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onDecline,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text('Decline'),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: onAccept,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              textStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}
