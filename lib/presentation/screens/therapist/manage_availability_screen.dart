import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/therapist_slot_model.dart';
import '../../../domain/providers/auth_provider.dart';

final _slotsProvider =
    StreamProvider.autoDispose.family<List<TherapistSlotModel>, String>(
        (ref, therapistId) {
  if (therapistId.isEmpty) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('therapistSlots')
      .where('therapistId', isEqualTo: therapistId)
      .orderBy('dateTime', descending: false)
      .snapshots()
      .map((s) => s.docs
          .map((d) => TherapistSlotModel.fromMap(d.id, d.data()))
          .toList());
});

class ManageAvailabilityScreen extends ConsumerStatefulWidget {
  const ManageAvailabilityScreen({super.key});

  @override
  ConsumerState<ManageAvailabilityScreen> createState() =>
      _ManageAvailabilityScreenState();
}

class _ManageAvailabilityScreenState
    extends ConsumerState<ManageAvailabilityScreen> {
  bool _adding = false;

  Future<void> _addSlot() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (pickedTime == null || !mounted) return;

    final slotDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() => _adding = true);
    try {
      await FirebaseFirestore.instance.collection('therapistSlots').add({
        'therapistId': user.uid,
        'dateTime': Timestamp.fromDate(slotDateTime),
        'durationMinutes': 60,
        'isAvailable': true,
        'bookedByPatientId': '',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Slot added'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add slot: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _deleteSlot(TherapistSlotModel slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Slot?'),
        content: Text(
            'Remove ${slot.formattedDate} at ${slot.formattedTime}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await FirebaseFirestore.instance
        .collection('therapistSlots')
        .doc(slot.slotId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final slotsAsync = ref.watch(_slotsProvider(user?.uid ?? ''));

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
          'Manage Availability',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adding ? null : _addSlot,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: _adding
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.add_rounded),
        label: const Text('Add Slot',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: slotsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (slots) {
          if (slots.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 56, color: AppColors.textHint),
                  SizedBox(height: 12),
                  Text(
                    'No slots added yet',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Tap + Add Slot to set your availability',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textHint),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: slots.length,
            itemBuilder: (context, i) {
              final slot = slots[i];
              final isPending = !slot.isAvailable;

              return _SlotCard(
                slot: slot,
                isPending: isPending,
                onDelete: isPending ? null : () => _deleteSlot(slot),
              )
                  .animate(delay: Duration(milliseconds: i * 50))
                  .fadeIn(duration: 250.ms)
                  .slideY(begin: 0.05, end: 0);
            },
          );
        },
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final TherapistSlotModel slot;
  final bool isPending;
  final VoidCallback? onDelete;

  const _SlotCard({
    required this.slot,
    required this.isPending,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPending
              ? AppColors.warning.withValues(alpha: 0.4)
              : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isPending
                  ? AppColors.warning.withValues(alpha: 0.1)
                  : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.access_time_rounded,
              color: isPending ? AppColors.warning : AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.formattedDate,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${slot.formattedTime}  ·  ${slot.durationMinutes} min',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isPending
                  ? AppColors.warning.withValues(alpha: 0.12)
                  : AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isPending ? 'Pending' : 'Available',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isPending ? AppColors.warning : AppColors.success,
              ),
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }
}
