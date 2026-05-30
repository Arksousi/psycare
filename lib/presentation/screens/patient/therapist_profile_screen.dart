// therapist_profile_screen.dart
// Detailed profile view for a therapist — shown before booking or connecting.
// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../data/models/therapist_model.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/therapist_provider.dart';

class TherapistProfileScreen extends ConsumerStatefulWidget {
  const TherapistProfileScreen({super.key});

  @override
  ConsumerState<TherapistProfileScreen> createState() =>
      _TherapistProfileScreenState();
}

class _TherapistProfileScreenState
    extends ConsumerState<TherapistProfileScreen> {
  bool _consentChecked = false;
  bool _sendingRequest = false;

  Future<void> _showConsentSheet(
      BuildContext context, TherapistModel therapist, String patientId, String patientName) async {
    setState(() => _consentChecked = false);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Connect with ${therapist.name}',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                'By connecting, this therapist will have access to your assessment results and journal entries so they can support you better.',
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _consentChecked,
                    activeColor: AppColors.primary,
                    onChanged: (v) {
                      setModal(() => _consentChecked = v ?? false);
                      setState(() => _consentChecked = v ?? false);
                    },
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'I consent to sharing my assessment and journal data with this therapist.',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _consentChecked && !_sendingRequest
                      ? () async {
                          Navigator.pop(ctx);
                          setState(() => _sendingRequest = true);
                          try {
                            await ref
                                .read(therapistConnectionServiceProvider)
                                .sendConnectionRequest(
                                  patientId: patientId,
                                  therapistId: therapist.uid,
                                  patientName: patientName,
                                  therapistName: therapist.name,
                                  initiatedBy: 'patient',
                                  consentGiven: true,
                                );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Connection request sent!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
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
                          } finally {
                            if (mounted) setState(() => _sendingRequest = false);
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Send Request',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final therapist =
        ModalRoute.of(context)?.settings.arguments as TherapistModel?;

    if (therapist == null) {
      return const Scaffold(
        body: Center(child: Text('Therapist not found')),
      );
    }

    final user = ref.watch(currentUserProvider);
    final connectionsAsync =
        ref.watch(patientTherapistConnectionsProvider(user?.uid ?? ''));

    // Determine connection status with this specific therapist
    final connectionStatus = connectionsAsync.valueOrNull
        ?.where((c) => c.therapistId == therapist.uid)
        .firstOrNull;
    final isConnected = connectionStatus?.isActive ?? false;
    final isPending = connectionStatus?.isPending ?? false;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Gradient header
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.dark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      _Avatar(therapist: therapist),
                      const SizedBox(height: 12),
                      Text(
                        therapist.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (therapist.specialization.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          therapist.specialization,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (therapist.rating > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star_rounded,
                                color: AppColors.warning, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '${therapist.rating.toStringAsFixed(1)} (${therapist.reviewCount})',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (therapist.bio.isNotEmpty) ...[
                    _SectionTitle(title: 'About'),
                    const SizedBox(height: 8),
                    Text(
                      therapist.bio,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                          ),
                    ).animate().fadeIn(delay: 100.ms),
                    const SizedBox(height: 24),
                  ],

                  if (therapist.specializedFields.isNotEmpty) ...[
                    _SectionTitle(title: 'Specializations'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: therapist.specializedFields
                          .map((f) => _InfoChip(label: f))
                          .toList(),
                    ).animate().fadeIn(delay: 150.ms),
                    const SizedBox(height: 24),
                  ],

                  if (therapist.languages.isNotEmpty) ...[
                    _SectionTitle(title: 'Languages'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: therapist.languages
                          .map((l) => _InfoChip(
                                label: l,
                                color: AppColors.accent,
                              ))
                          .toList(),
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 24),
                  ],

                  if (therapist.sessionTypes.isNotEmpty) ...[
                    _SectionTitle(title: 'Session Types'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: therapist.sessionTypes
                          .map((s) => _InfoChip(
                                label: s,
                                icon: _sessionIcon(s),
                              ))
                          .toList(),
                    ).animate().fadeIn(delay: 250.ms),
                    const SizedBox(height: 24),
                  ],

                  if (therapist.workingHours.isNotEmpty) ...[
                    _SectionTitle(title: 'Working Hours'),
                    const SizedBox(height: 8),
                    ...therapist.workingHours.entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text(
                                e.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              e.value,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (therapist.clinicLocation.isNotEmpty) ...[
                    _SectionTitle(title: 'Clinic Location'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            therapist.clinicLocation,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 24),
                  ],

                  // ── Connect button ────────────────────────────────────────
                  if (isConnected)
                    _ConnectedChip()
                  else if (isPending)
                    _PendingChip()
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _sendingRequest
                            ? null
                            : () => _showConsentSheet(
                                context,
                                therapist,
                                user?.uid ?? '',
                                user?.name ?? ''),
                        icon: _sendingRequest
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary),
                              )
                            : const Icon(Icons.person_add_rounded, size: 18),
                        label: const Text('Connect'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // ── Book Session button (always available) ────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.bookingConsent,
                        arguments: therapist,
                      ),
                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                      label: Text(context.tr('bookSession')),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 350.ms),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _sessionIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('person') || t.contains('in-person')) {
      return Icons.location_on_rounded;
    }
    return Icons.chat_bubble_rounded;
  }
}

class _ConnectedChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 18),
          SizedBox(width: 8),
          Text(
            'Connected',
            style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
                fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _PendingChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.textHint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.textHint.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule_rounded,
              color: AppColors.textSecondary, size: 18),
          SizedBox(width: 8),
          Text(
            'Request Sent',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final TherapistModel therapist;
  const _Avatar({required this.therapist});

  @override
  Widget build(BuildContext context) {
    if (therapist.profileImageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 44,
        backgroundImage: NetworkImage(therapist.profileImageUrl),
        backgroundColor: Colors.white.withValues(alpha: 0.2),
      );
    }
    final initials = therapist.name.isNotEmpty
        ? therapist.name
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join()
        : '?';
    return CircleAvatar(
      radius: 44,
      backgroundColor: Colors.white.withValues(alpha: 0.25),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.dark,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const _InfoChip({required this.label, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: c, size: 14),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: c,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
