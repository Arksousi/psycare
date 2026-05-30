import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/therapist_provider.dart';

class BrowseUnconnectedPatientsScreen extends ConsumerStatefulWidget {
  const BrowseUnconnectedPatientsScreen({super.key});

  @override
  ConsumerState<BrowseUnconnectedPatientsScreen> createState() =>
      _BrowseUnconnectedPatientsScreenState();
}

class _BrowseUnconnectedPatientsScreenState
    extends ConsumerState<BrowseUnconnectedPatientsScreen> {
  final Set<String> _pendingRequests = {};

  Future<void> _sendRequest(
      Map<String, dynamic> patient, String therapistId, String therapistName) async {
    final patientId = patient['uid'] as String;
    if (_pendingRequests.contains(patientId)) return;

    setState(() => _pendingRequests.add(patientId));

    try {
      await ref.read(therapistConnectionServiceProvider).sendConnectionRequest(
            patientId: patientId,
            therapistId: therapistId,
            patientName: patient['name'] as String? ?? 'Patient',
            therapistName: therapistName,
            initiatedBy: 'therapist',
            consentGiven: false,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection request sent'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _pendingRequests.remove(patientId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send request: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final patientsAsync = ref.watch(allPatientsForTherapistProvider);
    final connectionsAsync =
        ref.watch(therapistActiveConnectionsProvider(user?.uid ?? ''));
    final pendingAsync =
        ref.watch(therapistIncomingConnectionRequestsProvider(user?.uid ?? ''));

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
          'Browse Patients',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
      ),
      body: patientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (allPatients) {
          final connectedIds = connectionsAsync.valueOrNull
                  ?.map((c) => c.patientId)
                  .toSet() ??
              {};
          final pendingIds = pendingAsync.valueOrNull
                  ?.map((c) => c.patientId)
                  .toSet() ??
              {};

          // Filter out already-connected patients
          final unconnected = allPatients
              .where((p) => !connectedIds.contains(p['uid'] as String))
              .toList();

          if (unconnected.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline,
                      size: 56, color: AppColors.textHint),
                  SizedBox(height: 12),
                  Text(
                    'No unconnected patients found',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 15),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: unconnected.length,
            itemBuilder: (context, i) {
              final patient = unconnected[i];
              final patientId = patient['uid'] as String;
              final name = patient['name'] as String? ?? 'Patient';
              final isPending = pendingIds.contains(patientId) ||
                  _pendingRequests.contains(patientId);

              return _PatientCard(
                name: name,
                initials: _initials(name),
                isPending: isPending,
                onSendRequest: isPending
                    ? null
                    : () => _sendRequest(
                        patient, user?.uid ?? '', user?.name ?? ''),
              )
                  .animate(delay: Duration(milliseconds: i * 60))
                  .fadeIn(duration: 280.ms)
                  .slideY(begin: 0.06, end: 0);
            },
          );
        },
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final String name;
  final String initials;
  final bool isPending;
  final VoidCallback? onSendRequest;

  const _PatientCard({
    required this.name,
    required this.initials,
    required this.isPending,
    required this.onSendRequest,
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
            child: Text(
              name,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
          ),
          if (isPending)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.textHint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Request Sent',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500),
              ),
            )
          else
            ElevatedButton(
              onPressed: onSendRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
              child: const Text('Connect'),
            ),
        ],
      ),
    );
  }
}
