import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/journal_model.dart';
import '../../../data/repositories/journal_repository.dart';

final _journalEntriesProvider =
    StreamProvider.autoDispose.family<List<JournalEntry>, ({String patientId, String therapistId})>(
  (ref, args) => ref
      .read(journalRepositoryProvider)
      .streamEntries(patientId: args.patientId, therapistId: args.therapistId),
);

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _controller = TextEditingController();
  String _selectedMood = 'okay';
  bool _submitting = false;
  late String _patientId;
  late String _therapistId;
  bool _readOnly = false;

  static const _moods = ['great', 'okay', 'sad', 'anxious', 'angry'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _patientId = args?['patientId'] as String? ?? '';
    _therapistId = args?['therapistId'] as String? ?? '';
    _readOnly = args?['readOnly'] as bool? ?? false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref.read(journalRepositoryProvider).addEntry(
            patientId: _patientId,
            therapistId: _therapistId,
            content: text,
            mood: _selectedMood,
          );
      _controller.clear();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(_journalEntriesProvider(
        (patientId: _patientId, therapistId: _therapistId)));

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _readOnly ? 'Patient Journal' : 'My Journal',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _readOnly
                              ? 'Read-only — patient\'s entries'
                              : 'Your doctor can see these entries',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: 20),

              // Entry composer (hidden for therapist read-only view)
              if (!_readOnly) Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
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
                      // Mood picker
                      const Text(
                        'How are you feeling?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: _moods.map((mood) {
                          final selected = _selectedMood == mood;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedMood = mood),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                JournalEntry.moodEmoji(mood),
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 12),
                      const Divider(color: AppColors.border, height: 1),
                      const SizedBox(height: 12),

                      // Text field
                      TextField(
                        controller: _controller,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Write your thoughts here…',
                          hintStyle: TextStyle(
                              color: AppColors.textHint, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Submit
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save Entry',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.08, end: 0),

              const SizedBox(height: 20),

              // Past entries
              Expanded(
                child: entriesAsync.when(
                  data: (entries) {
                    if (entries.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.book_outlined,
                                color: AppColors.textHint, size: 48),
                            SizedBox(height: 12),
                            Text(
                              'No entries yet',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Write your first entry above',
                              style: TextStyle(
                                  color: AppColors.textHint, fontSize: 13),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms);
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) =>
                          _EntryCard(entry: entries[i], index: i),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (e, _) => Center(
                    child: Text(e.toString(),
                        style: const TextStyle(color: AppColors.textSecondary)),
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

class _EntryCard extends StatelessWidget {
  final JournalEntry entry;
  final int index;

  const _EntryCard({required this.entry, required this.index});

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return 'Today $h:$m';
    }
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(JournalEntry.moodEmoji(entry.mood),
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                _formatDate(entry.createdAt),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textHint),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.content,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (index * 50).ms, duration: 300.ms)
        .slideY(begin: 0.05, end: 0);
  }
}
