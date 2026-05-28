// therapist_profile_edit_screen.dart
// Allows a therapist to complete and update their public profile.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/therapist_model.dart';
import '../../../data/repositories/therapist_repository.dart';
import '../../../domain/providers/auth_provider.dart';

class TherapistProfileEditScreen extends ConsumerStatefulWidget {
  const TherapistProfileEditScreen({super.key});

  @override
  ConsumerState<TherapistProfileEditScreen> createState() =>
      _TherapistProfileEditScreenState();
}

class _TherapistProfileEditScreenState
    extends ConsumerState<TherapistProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  final _specializationCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();
  final _fieldsCtrl = TextEditingController();
  final _langsCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  final Set<String> _selectedSessionTypes = {};

  TherapistModel? _current;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _sessionTypeOptions = ['Chat', 'Video', 'In-Person'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _specializationCtrl.dispose();
    _bioCtrl.dispose();
    _nationalityCtrl.dispose();
    _yearsCtrl.dispose();
    _fieldsCtrl.dispose();
    _langsCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = ref.read(currentUserProvider)?.uid ?? '';
    try {
      final therapist = await TherapistRepository().getTherapist(uid);
      if (mounted && therapist != null) {
        _current = therapist;
        _specializationCtrl.text = therapist.specialization;
        _bioCtrl.text = therapist.bio;
        _nationalityCtrl.text = therapist.nationality;
        _yearsCtrl.text =
            therapist.yearsOfExperience > 0
                ? therapist.yearsOfExperience.toString()
                : '';
        _fieldsCtrl.text = therapist.specializedFields.join(', ');
        _langsCtrl.text = therapist.languages.join(', ');
        _locationCtrl.text = therapist.clinicLocation;
        _selectedSessionTypes
          ..clear()
          ..addAll(therapist.sessionTypes);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _current == null) return;
    setState(() => _saving = true);

    final updated = _current!.copyWith(
      specialization: _specializationCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      nationality: _nationalityCtrl.text.trim(),
      yearsOfExperience: int.tryParse(_yearsCtrl.text.trim()) ?? 0,
      specializedFields: _fieldsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      languages: _langsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      sessionTypes: _selectedSessionTypes.toList(),
      clinicLocation: _locationCtrl.text.trim(),
    );

    try {
      await TherapistRepository().updateProfile(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 1,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary, size: 20),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: _save,
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style:
                          const TextStyle(color: AppColors.textSecondary)))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _SectionHeader(title: 'Basic Info'),
                      const SizedBox(height: 12),
                      _Field(
                        label: 'Specialization',
                        hint: 'e.g. Cognitive Behavioral Therapy',
                        controller: _specializationCtrl,
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        label: 'Nationality',
                        hint: 'e.g. Saudi',
                        controller: _nationalityCtrl,
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        label: 'Years of Experience',
                        hint: 'e.g. 5',
                        controller: _yearsCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                      ),
                      const SizedBox(height: 24),
                      _SectionHeader(title: 'About'),
                      const SizedBox(height: 12),
                      _Field(
                        label: 'Bio',
                        hint:
                            'Tell patients about your approach and experience...',
                        controller: _bioCtrl,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 24),
                      _SectionHeader(title: 'Expertise'),
                      const SizedBox(height: 12),
                      _Field(
                        label: 'Specialized Fields',
                        hint: 'Anxiety, Depression, Trauma (comma-separated)',
                        controller: _fieldsCtrl,
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        label: 'Languages',
                        hint: 'English, Arabic (comma-separated)',
                        controller: _langsCtrl,
                      ),
                      const SizedBox(height: 24),
                      _SectionHeader(title: 'Session Types'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        children: _sessionTypeOptions.map((type) {
                          final selected =
                              _selectedSessionTypes.contains(type);
                          return FilterChip(
                            label: Text(type),
                            selected: selected,
                            onSelected: (v) => setState(() {
                              if (v) {
                                _selectedSessionTypes.add(type);
                              } else {
                                _selectedSessionTypes.remove(type);
                              }
                            }),
                            selectedColor:
                                AppColors.primary.withValues(alpha: 0.15),
                            checkmarkColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                            backgroundColor: AppColors.surface,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      _SectionHeader(title: 'Location'),
                      const SizedBox(height: 12),
                      _Field(
                        label: 'Clinic Location',
                        hint: 'e.g. King Fahd Road, Riyadh',
                        controller: _locationCtrl,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Save Profile'),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ].animate(interval: 40.ms).fadeIn(duration: 250.ms),
                  ),
                ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: AppColors.textHint, fontSize: 13),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
