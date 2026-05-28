import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../data/models/volunteer_model.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/patient_provider.dart';
import '../../../domain/providers/volunteer_provider.dart';

class VolunteerProfileScreen extends ConsumerStatefulWidget {
  const VolunteerProfileScreen({super.key});

  @override
  ConsumerState<VolunteerProfileScreen> createState() =>
      _VolunteerProfileScreenState();
}

class _VolunteerProfileScreenState
    extends ConsumerState<VolunteerProfileScreen> {
  bool _requesting = false;

  Future<void> _sendRequest(VolunteerModel volunteer) async {
    setState(() => _requesting = true);
    try {
      final user = ref.read(currentUserProvider);
      final patient = ref.read(currentPatientProvider).valueOrNull;
      if (user == null) return;

      await ref.read(volunteerServiceProvider).sendConnectionRequest(
            patientId: user.uid,
            volunteerId: volunteer.volunteerId,
            therapistId: patient?.therapistId ?? '',
            patientName: user.name,
            volunteerName: volunteer.name,
            initiatedBy: 'patient',
          );
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _showRequestDialog(VolunteerModel volunteer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.tr('connectConfirmTitle'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          context
              .tr('connectConfirmBody')
              .replaceAll('{name}', volunteer.name),
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('notNow'),
                style:
                    const TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(context.tr('sendRequest')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _sendRequest(volunteer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final volunteer =
        ModalRoute.of(context)?.settings.arguments as VolunteerModel?;
    if (volunteer == null) {
      return const Scaffold(body: Center(child: Text('No volunteer data')));
    }

    final patientId = ref.watch(currentUserProvider)?.uid ?? '';
    final connectionsAsync =
        ref.watch(patientAllConnectionsProvider(patientId));
    final existingConn = connectionsAsync.valueOrNull
        ?.where((c) => c.volunteerId == volunteer.volunteerId)
        .firstOrNull;

    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header with back button
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                  Icons.arrow_back_ios_rounded,
                                  color: AppColors.textPrimary,
                                  size: 20),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Avatar
                      CircleAvatar(
                        radius: 48,
                        backgroundImage:
                            volunteer.profilePhoto.isNotEmpty
                                ? NetworkImage(volunteer.profilePhoto)
                                : null,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.12),
                        child: volunteer.profilePhoto.isEmpty
                            ? Text(
                                volunteer.initials,
                                style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary),
                              )
                            : null,
                      ).animate().scale(
                          duration: 500.ms, curve: Curves.elasticOut),

                      const SizedBox(height: 16),

                      // Name
                      Text(
                        volunteer.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ).animate().fadeIn(delay: 100.ms),

                      const SizedBox(height: 8),

                      // Specialization badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          volunteer.specialization,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ).animate().fadeIn(delay: 150.ms),

                      const SizedBox(height: 6),

                      Text(
                        '${volunteer.university} • ${volunteer.yearOfStudy}',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary),
                      ).animate().fadeIn(delay: 180.ms),

                      const SizedBox(height: 8),

                      // Star rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Color(0xFFF59E0B), size: 18),
                          const SizedBox(width: 4),
                          Text(
                            volunteer.ratingCount > 0
                                ? '${volunteer.rating.toStringAsFixed(1)} (${volunteer.ratingCount} ${context.tr('reviews')})'
                                : context.tr('newVolunteer'),
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ).animate().fadeIn(delay: 200.ms),

                      const SizedBox(height: 24),
                      const Divider(
                          color: AppColors.border, height: 1),
                      const SizedBox(height: 24),

                      // About section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('about'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              volunteer.bio.isNotEmpty
                                  ? volunteer.bio
                                  : context.tr('noBio'),
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  height: 1.6),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 250.ms),

                      const SizedBox(height: 24),

                      // Stats row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            _StatChip(
                              icon: Icons.access_time_rounded,
                              value: '${volunteer.volunteerHours}',
                              label: context.tr('volunteerHrs'),
                            ),
                            const SizedBox(width: 10),
                            _StatChip(
                              icon: Icons.people_rounded,
                              value:
                                  '${volunteer.connectedPatients.length}',
                              label: context.tr('patients'),
                            ),
                            const SizedBox(width: 10),
                            _StatChip(
                              icon: Icons.star_rounded,
                              value: volunteer.ratingCount > 0
                                  ? volunteer.rating.toStringAsFixed(1)
                                  : '—',
                              label: context.tr('rating'),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 300.ms),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Bottom CTA
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: existingConn != null && existingConn.status == 'active'
                    // Active connection → open chat
                    ? ElevatedButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.volunteerChat,
                          arguments: {
                            'sessionId': existingConn.chatId,
                            'volunteerId': volunteer.volunteerId,
                            'connectionId': existingConn.connectionId,
                            'isVolunteer': false,
                          },
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          context.tr('openChat'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      )
                    : existingConn != null && existingConn.isPending
                        // Pending connection → show awaiting state
                        ? Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.3)),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              context.tr('requestPending'),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary),
                            ),
                          )
                        // No connection → send request
                        : ElevatedButton(
                            onPressed: _requesting
                                ? null
                                : () => _showRequestDialog(volunteer),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _requesting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : Text(
                                    '${context.tr('connectWith')} ${volunteer.name} 💙',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                          ),
              ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatChip(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}
