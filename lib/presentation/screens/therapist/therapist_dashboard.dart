// therapist_dashboard.dart
// Main dashboard for therapists — shows overview stats and navigation.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/booking_provider.dart';
import '../../../domain/providers/chat_provider.dart' show pendingImmediateRequestsProvider;
import '../../../data/models/patient_model.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../domain/providers/therapist_provider.dart'
    show
        availableImmediateCountProvider,
        currentTherapistProvider,
        therapistPatientsProvider,
        therapistIncomingConnectionRequestsProvider;

/// Therapist home screen showing a summary of their patient load.
class TherapistDashboard extends ConsumerWidget {
  const TherapistDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final patientsAsync = ref.watch(therapistPatientsProvider);
    final pendingBookings =
        ref.watch(pendingBookingsProvider(user?.uid ?? ''));
    final therapist = ref.watch(currentTherapistProvider).valueOrNull;
    final availableCount = ref
        .watch(availableImmediateCountProvider)
        .maybeWhen(data: (n) => n, orElse: () => 0);

    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          children: [
                            Image.asset('assets/images/logo.png',
                                width: 64, height: 64),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${context.tr('goodDay')}, 👨‍⚕️',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    user?.name ?? context.tr('roleTherapist'),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideX(
                          begin: -0.1, end: 0),
                      // Edit profile button
                      IconButton(
                        onPressed: () => Navigator.pushNamed(
                            context, AppRoutes.therapistProfileEdit),
                        icon: const Icon(Icons.edit_rounded,
                            color: AppColors.textSecondary),
                        tooltip: 'Edit Profile',
                      ),
                      // Settings button
                      IconButton(
                        onPressed: () => Navigator.pushNamed(
                            context, AppRoutes.settings),
                        icon: const Icon(Icons.settings_rounded,
                            color: AppColors.textSecondary),
                        tooltip: context.tr('settings'),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // Stats row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: patientsAsync.when(
                    data: (patients) => Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: context.tr('totalPatients'),
                            value: '${patients.length}',
                            icon: Icons.people_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _StatCard(
                            label: context.tr('submitted'),
                            value:
                                '${patients.where((p) => p.submittedAt != null).length}',
                            icon: Icons.assignment_turned_in_rounded,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    loading: () => const _StatsRowSkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Assigned patients section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _AssignedPatientsSection(
                    patientsAsync: patientsAsync,
                    therapistId: user?.uid ?? '',
                  ),
                ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.1, end: 0),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Upcoming confirmed sessions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _UpcomingSessionsSection(
                      therapistId: user?.uid ?? ''),
                ).animate().fadeIn(delay: 242.ms).slideY(begin: 0.1, end: 0),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Manage availability card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: const _ManageAvailabilityCard(),
                ).animate().fadeIn(delay: 255.ms).slideY(begin: 0.1, end: 0),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Connection requests card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _ConnectionRequestsCard(therapistId: user?.uid ?? ''),
                ).animate().fadeIn(delay: 260.ms).slideY(begin: 0.1, end: 0),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Browse patients card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: const _BrowsePatientsCard(),
                ).animate().fadeIn(delay: 270.ms).slideY(begin: 0.1, end: 0),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Session booking requests card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _SessionRequestsCard(
                    pendingCount: pendingBookings.whenData((l) => l.length).value ?? 0,
                  ),
                ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.1, end: 0),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Incoming requests card (gated on isAvailableForImmediate)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (therapist?.isAvailableForImmediate == true)
                        _IncomingRequestsCard()
                      else
                        const _UnavailableForImmediateNudge(),
                      const SizedBox(height: 6),
                      Text(
                        '$availableCount ${availableCount == 1 ? "doctor" : "doctors"} available for immediate chat',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textHint),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 320.ms).slideY(begin: 0.1, end: 0),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Info card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _InfoCard(),
                ).animate().fadeIn(delay: 460.ms),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRowSkeleton extends StatelessWidget {
  const _StatsRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionRequestsCard extends StatelessWidget {
  final int pendingCount;
  const _SessionRequestsCard({required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, AppRoutes.bookingRequests),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.event_note_rounded,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('sessionRequests'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    context.tr('sessionRequestsSubtitle'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (pendingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$pendingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppColors.textHint, size: 16),
          ],
        ),
      ),
    );
  }
}

class _IncomingRequestsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref
        .watch(pendingImmediateRequestsProvider)
        .maybeWhen(data: (list) => list.length, orElse: () => 0);

    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, AppRoutes.incomingRequests),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.error.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_active_rounded,
                      color: AppColors.error, size: 22),
                ),
                if (count > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('incomingRequests'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    context.tr('patientsWaiting'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textHint, size: 16),
          ],
        ),
      ),
    );
  }
}

class _UnavailableForImmediateNudge extends StatelessWidget {
  const _UnavailableForImmediateNudge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.bolt_rounded, color: AppColors.textHint, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Enable "Available for Immediate" in Settings to receive incoming requests.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignedPatientsSection extends ConsumerStatefulWidget {
  final AsyncValue<List<PatientModel>> patientsAsync;
  final String therapistId;

  const _AssignedPatientsSection({
    required this.patientsAsync,
    required this.therapistId,
  });

  @override
  ConsumerState<_AssignedPatientsSection> createState() =>
      _AssignedPatientsSectionState();
}

class _AssignedPatientsSectionState
    extends ConsumerState<_AssignedPatientsSection> {
  bool _openingChat = false;

  Future<void> _openChat(PatientModel patient) async {
    if (_openingChat) return;
    setState(() => _openingChat = true);
    try {
      final sessionId = await ref
          .read(chatRepositoryProvider)
          .getOrCreateDirectSession(
            patientId: patient.uid,
            therapistId: widget.therapistId,
          );
      if (mounted) {
        await Navigator.pushNamed(
          context,
          AppRoutes.chat,
          arguments: {'sessionId': sessionId, 'therapistId': widget.therapistId},
        );
      }
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  Color _severityColor(PatientModel p) {
    if (p.submittedAt == null) return AppColors.textHint;
    final s = p.totalScore;
    if (s <= 17) return AppColors.success;
    if (s <= 35) return const Color(0xFFF59E0B);
    if (s <= 53) return const Color(0xFFF97316);
    return AppColors.error;
  }

  String _severityLabel(PatientModel p) {
    if (p.submittedAt == null) return 'No assessment';
    final s = p.totalScore;
    if (s <= 17) return 'Minimal';
    if (s <= 35) return 'Mild';
    if (s <= 53) return 'Moderate';
    return 'Severe';
  }

  @override
  Widget build(BuildContext context) {
    return widget.patientsAsync.when(
      loading: () => Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (patients) {
        final shown = patients.length > 3 ? patients.sublist(0, 3) : patients;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Your Patients',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${patients.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (patients.length > 3)
                  GestureDetector(
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.patientList),
                    child: const Text(
                      'See All →',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (patients.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.people_outline_rounded,
                        color: AppColors.textHint, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'No patients assigned yet',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              )
            else
              ...shown.map((patient) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PatientBubbleCard(
                      patient: patient,
                      severityLabel: _severityLabel(patient),
                      severityColor: _severityColor(patient),
                      openingChat: _openingChat,
                      onMessage: () => _openChat(patient),
                      onJournal: () => Navigator.pushNamed(
                        context,
                        AppRoutes.journal,
                        arguments: {
                          'patientId': patient.uid,
                          'therapistId': widget.therapistId,
                          'readOnly': true,
                        },
                      ),
                      onAssessment: () => Navigator.pushNamed(
                        context,
                        AppRoutes.patientDetail,
                        arguments: patient,
                      ),
                    ),
                  )),

            if (patients.length > 3)
              GestureDetector(
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.patientList),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'See all ${patients.length} patients →',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PatientBubbleCard extends StatelessWidget {
  final PatientModel patient;
  final String severityLabel;
  final Color severityColor;
  final bool openingChat;
  final VoidCallback onMessage;
  final VoidCallback onJournal;
  final VoidCallback onAssessment;

  const _PatientBubbleCard({
    required this.patient,
    required this.severityLabel,
    required this.severityColor,
    required this.openingChat,
    required this.onMessage,
    required this.onJournal,
    required this.onAssessment,
  });

  String get _initials {
    final parts = patient.name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
          // Patient info row
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  _initials,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (patient.email.isNotEmpty)
                      Text(
                        patient.email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: severityColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  severityLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: severityColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: AppColors.border.withValues(alpha: 0.6), height: 1),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _BubbleAction(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Message',
                  loading: openingChat,
                  onTap: onMessage,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BubbleAction(
                  icon: Icons.book_rounded,
                  label: 'Journal',
                  onTap: onJournal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BubbleAction(
                  icon: Icons.assignment_rounded,
                  label: 'Assessment',
                  onTap: onAssessment,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BubbleAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool loading;

  const _BubbleAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: AppColors.primary),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _UpcomingSessionsSection extends ConsumerWidget {
  final String therapistId;
  const _UpcomingSessionsSection({required this.therapistId});

  String _fmt(DateTime dt) =>
      '${DateFormat('EEE d MMM').format(dt)}  ·  ${DateFormat('h:mm a').format(dt)}';

  String _sessionIcon(String type) => type == 'in-person' ? '📍' : '💬';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(confirmedBookingsProvider(therapistId));

    return bookingsAsync.maybeWhen(
      data: (all) {
        final upcoming = all
            .where((b) => b.scheduledAt != null)
            .toList()
          ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
        final shown = upcoming.take(3).toList();

        if (shown.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Upcoming Sessions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(
                      context, AppRoutes.bookingRequests),
                  child: const Text(
                    'See All →',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...shown.map((booking) {
              final initials = booking.patientName.isNotEmpty
                  ? booking.patientName
                      .trim()
                      .split(' ')
                      .where((w) => w.isNotEmpty)
                      .take(2)
                      .map((w) => w[0].toUpperCase())
                      .join()
                  : '?';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.35),
                      width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          AppColors.success.withValues(alpha: 0.12),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.patientName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                _sessionIcon(booking.sessionType),
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _fmt(booking.scheduledAt!),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 18),
                  ],
                ),
              );
            }),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _ManageAvailabilityCard extends StatelessWidget {
  const _ManageAvailabilityCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, AppRoutes.manageAvailability),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage Availability',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Set your available time slots for patients',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textHint, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ConnectionRequestsCard extends ConsumerWidget {
  final String therapistId;
  const _ConnectionRequestsCard({required this.therapistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref
        .watch(therapistIncomingConnectionRequestsProvider(therapistId))
        .maybeWhen(data: (list) => list.length, orElse: () => 0);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
          context, AppRoutes.therapistConnectionRequests),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_add_rounded,
                      color: AppColors.accent, size: 22),
                ),
                if (count > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connection Requests',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Text(
                    'Patients who want to connect with you',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (count > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppColors.textHint, size: 16),
          ],
        ),
      ),
    );
  }
}

class _BrowsePatientsCard extends StatelessWidget {
  const _BrowsePatientsCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, AppRoutes.therapistBrowsePatients),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.search_rounded,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Browse Patients',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Find and connect with new patients',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textHint, size: 16),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.accentLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_rounded,
              color: AppColors.accent, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              context.tr('aiInsightTip'),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
