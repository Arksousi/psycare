// booking_consent_screen.dart
// Session type selection, slot picker, and data-sharing consent before confirming a booking.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../data/models/therapist_model.dart';
import '../../../data/models/therapist_slot_model.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/booking_provider.dart';

final _availableSlotsProvider =
    StreamProvider.autoDispose.family<List<TherapistSlotModel>, String>(
        (ref, therapistId) {
  if (therapistId.isEmpty) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('therapistSlots')
      .where('therapistId', isEqualTo: therapistId)
      .where('isAvailable', isEqualTo: true)
      .orderBy('dateTime', descending: false)
      .snapshots()
      .map((s) => s.docs
          .map((d) => TherapistSlotModel.fromMap(d.id, d.data()))
          .toList());
});

class BookingConsentScreen extends ConsumerStatefulWidget {
  const BookingConsentScreen({super.key});

  @override
  ConsumerState<BookingConsentScreen> createState() =>
      _BookingConsentScreenState();
}

class _BookingConsentScreenState
    extends ConsumerState<BookingConsentScreen> {
  bool _consentChecked = false;
  TherapistSlotModel? _selectedSlot;

  Future<void> _confirmBooking(TherapistModel therapist) async {
    final user = ref.read(currentUserProvider);
    final notifier = ref.read(bookingProvider.notifier);

    await notifier.createBooking(
      patientId: user?.uid ?? '',
      patientName: user?.name ?? '',
      therapistId: therapist.uid,
      therapistName: therapist.name,
      sessionType: 'in-person',
      scheduledAt: _selectedSlot?.dateTime,
      slotId: _selectedSlot?.slotId,
    );

    if (!mounted) return;

    final state = ref.read(bookingProvider);
    if (state.success) {
      _showSuccessDialog(context, therapist);
    } else if (state.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${context.tr('failedTo')} ${state.errorMessage}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showSuccessDialog(BuildContext context, TherapistModel therapist) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('requestSent'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.dark,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              '${context.tr('bookingConfirmed')} ${therapist.name}. ${context.tr('bookingConfirmed2')}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_selectedSlot != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: AppColors.primary, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      _selectedSlot!.formattedDateTime,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamedAndRemoveUntil(
                      context, AppRoutes.patientDashboard, (_) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(context.tr('backToDashboard')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final therapist =
        ModalRoute.of(context)?.settings.arguments as TherapistModel?;
    final bookingState = ref.watch(bookingProvider);

    if (therapist == null) {
      return const Scaffold(body: Center(child: Text('No therapist')));
    }

    final slotsAsync = ref.watch(_availableSlotsProvider(therapist.uid));

    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      color: AppColors.textPrimary, size: 20),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 20),

                // Therapist mini-card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      _Avatar(therapist: therapist),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              therapist.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (therapist.specialization.isNotEmpty)
                              Text(
                                therapist.specialization,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 24),

                // Session badge — in-person only
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          color: AppColors.primary, size: 18),
                      SizedBox(width: 10),
                      Text(
                        'In-Person Session',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 150.ms),

                // Clinic location
                if (therapist.clinicLocation.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Clinic Location',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.place_rounded,
                            color: AppColors.textSecondary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            therapist.clinicLocation,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                ],

                const SizedBox(height: 28),

                // ── Slot picker ───────────────────────────────────────────
                Text(
                  'Choose a Time Slot',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ).animate().fadeIn(delay: 230.ms),
                const SizedBox(height: 12),

                slotsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (slots) {
                    if (slots.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.border.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: AppColors.textHint, size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No time slots available yet — your request will be sent without a scheduled time.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 250.ms);
                    }

                    return Column(
                      children: slots.map((slot) {
                        final isSelected =
                            _selectedSlot?.slotId == slot.slotId;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _selectedSlot =
                                isSelected ? null : slot;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 18,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        slot.formattedDate,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${slot.formattedTime}  ·  ${slot.durationMinutes} min',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isSelected
                                              ? Colors.white
                                                  .withValues(alpha: 0.85)
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle_rounded,
                                      color: Colors.white, size: 18),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ).animate().fadeIn(delay: 250.ms),

                const SizedBox(height: 28),

                // Consent
                Text(
                  context.tr('dataSharingConsent'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${context.tr('consentBody')} ${therapist.name}. ${context.tr('consentBody2')}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ).animate().fadeIn(delay: 350.ms),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () =>
                      setState(() => _consentChecked = !_consentChecked),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _consentChecked
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _consentChecked
                                ? AppColors.primary
                                : AppColors.border,
                            width: 2,
                          ),
                        ),
                        child: _consentChecked
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 14)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr('consentCheckbox'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),

                const SizedBox(height: 32),

                // Confirm button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_consentChecked && !bookingState.isLoading)
                        ? () => _confirmBooking(therapist)
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.border,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    child: bookingState.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(context.tr('confirmBooking')),
                  ),
                ).animate().fadeIn(delay: 450.ms),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
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
        radius: 24,
        backgroundImage: NetworkImage(therapist.profileImageUrl),
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
      radius: 24,
      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
