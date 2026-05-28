import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/volunteer_provider.dart';

class BrowsePatientsScreen extends ConsumerWidget {
  const BrowsePatientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final uid = user?.uid ?? '';
    final patientsAsync = ref.watch(allPatientsProvider);
    final connectionsAsync = ref.watch(volunteerConnectionsProvider(uid));

    final connectionMap = <String, String>{};
    for (final conn in connectionsAsync.valueOrNull ?? []) {
      connectionMap[conn.patientId] = conn.status;
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios_rounded,
                          color: AppColors.textPrimary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('browsePatients'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          context.tr('browsePatientsSub'),
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: patientsAsync.when(
                  skipLoadingOnReload: true,
                  data: (patients) {
                    final filtered =
                        patients.where((p) => p['uid'] != uid).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline_rounded,
                                color: AppColors.primary.withValues(alpha: 0.4),
                                size: 56),
                            const SizedBox(height: 16),
                            Text(
                              context.tr('noPatientsFound'),
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Patients will appear here once they sign up',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final patient = filtered[i];
                        final patientId = patient['uid'] as String;
                        final name = patient['name'] as String? ?? '';
                        final firstName =
                            name.trim().split(' ').firstWhere(
                                (p) => p.isNotEmpty,
                                orElse: () => '');
                        final initial = firstName.isNotEmpty
                            ? firstName[0].toUpperCase()
                            : '?';
                        final connStatus = connectionMap[patientId];

                        return _PatientCard(
                          firstName: firstName.isEmpty ? '—' : firstName,
                          initial: initial,
                          connStatus: connStatus,
                          onSendRequest: connStatus == null
                              ? () => ref
                                  .read(volunteerServiceProvider)
                                  .sendConnectionRequest(
                                    patientId: patientId,
                                    volunteerId: uid,
                                    therapistId: '',
                                    patientName: name,
                                    volunteerName: user?.name ?? '',
                                    initiatedBy: 'volunteer',
                                  )
                              : null,
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary)),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.error, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            e.toString(),
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
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

class _PatientCard extends StatefulWidget {
  final String firstName;
  final String initial;
  final String? connStatus;
  final Future<void> Function()? onSendRequest;

  const _PatientCard({
    required this.firstName,
    required this.initial,
    required this.connStatus,
    required this.onSendRequest,
  });

  @override
  State<_PatientCard> createState() => _PatientCardState();
}

class _PatientCardState extends State<_PatientCard> {
  bool _sending = false;

  Future<void> _handleSend() async {
    if (widget.onSendRequest == null) return;
    setState(() => _sending = true);
    try {
      await widget.onSendRequest!();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.connStatus;
    final canSend = status == null && widget.onSendRequest != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.accent.withValues(alpha: 0.15),
            child: Text(
              widget.initial,
              style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),

          // Name
          Expanded(
            child: Text(
              widget.firstName,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 8),

          // Status / action
          if (status == 'active')
            _StatusChip(
                label: context.tr('connected'), color: AppColors.success)
          else if (status == 'pending')
            _StatusChip(
                label: context.tr('requestSent'), color: AppColors.primary)
          else if (status == 'declined')
            _StatusChip(
                label: context.tr('requestDeclined'),
                color: AppColors.textHint)
          else if (canSend)
            GestureDetector(
              onTap: _sending ? null : _handleSend,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _sending
                      ? AppColors.primary.withValues(alpha: 0.6)
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        context.tr('sendRequest'),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
