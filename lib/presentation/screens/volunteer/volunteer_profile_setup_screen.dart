import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/volunteer_provider.dart';

class VolunteerProfileSetupScreen extends ConsumerStatefulWidget {
  const VolunteerProfileSetupScreen({super.key});

  @override
  ConsumerState<VolunteerProfileSetupScreen> createState() =>
      _VolunteerProfileSetupScreenState();
}

class _VolunteerProfileSetupScreenState
    extends ConsumerState<VolunteerProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _universityController = TextEditingController();
  final _bioController = TextEditingController();

  String _specialization = 'Psychology';
  String _yearOfStudy = '1st Year';
  bool _isAvailable = true;
  bool _saving = false;
  bool _initialized = false;

  static const _specializations = [
    'Psychology',
    'Medicine',
    'Social Work',
    'Nursing',
    'Other',
  ];

  static const _years = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    '5th Year',
    'Graduate',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _universityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final uid = ref.read(currentUserProvider)?.uid;
      if (uid == null || uid.isEmpty) {
        throw Exception('Not signed in');
      }
      await ref.read(volunteerServiceProvider).updateVolunteerProfile(uid, {
        'name': _nameController.text.trim(),
        'university': _universityController.text.trim(),
        'specialization': _specialization,
        'yearOfStudy': _yearOfStudy,
        'bio': _bioController.text.trim(),
        'isAvailable': _isAvailable,
      });
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.volunteerDashboard);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final volunteerAsync = ref.watch(currentVolunteerProvider);
    final authUser = ref.watch(currentUserProvider);

    if (!_initialized) {
      final vol = volunteerAsync.valueOrNull;
      if (vol != null) {
        _nameController.text = vol.name;
        _universityController.text = vol.university;
        _bioController.text = vol.bio;
        if (vol.specialization.isNotEmpty) _specialization = vol.specialization;
        if (vol.yearOfStudy.isNotEmpty) _yearOfStudy = vol.yearOfStudy;
        _isAvailable = vol.isAvailable;
        _initialized = true;
      } else if (!volunteerAsync.isLoading && authUser != null) {
        _nameController.text = authUser.name;
        _initialized = true;
      }
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),

                  // Header
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.school_rounded,
                              color: AppColors.primary, size: 36),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('volunteerSetupTitle'),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr('volunteerSetupSubtitle'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms),

                  const SizedBox(height: 32),

                  // Name
                  _label(context.tr('fullName')),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration(context.tr('fullName')),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.tr('fieldRequired')
                        : null,
                  ).animate().fadeIn(delay: 80.ms),

                  const SizedBox(height: 16),

                  // University
                  _label(context.tr('university')),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _universityController,
                    decoration: _inputDecoration(
                        context.tr('universityHint')),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.tr('fieldRequired')
                        : null,
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 16),

                  // Specialization
                  _label(context.tr('specialization')),
                  const SizedBox(height: 6),
                  _dropdown(
                    value: _specialization,
                    items: _specializations,
                    onChanged: (v) =>
                        setState(() => _specialization = v ?? _specialization),
                  ).animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: 16),

                  // Year of study
                  _label(context.tr('yearOfStudy')),
                  const SizedBox(height: 6),
                  _dropdown(
                    value: _yearOfStudy,
                    items: _years,
                    onChanged: (v) =>
                        setState(() => _yearOfStudy = v ?? _yearOfStudy),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 16),

                  // Bio
                  _label(context.tr('bio')),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _bioController,
                    maxLines: 4,
                    maxLength: 200,
                    decoration: _inputDecoration(context.tr('bioHint')),
                  ).animate().fadeIn(delay: 250.ms),

                  const SizedBox(height: 8),

                  // Availability toggle
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.tr('availableToConnect'),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Switch(
                          value: _isAvailable,
                          activeThumbColor: AppColors.primary,
                          activeTrackColor:
                              AppColors.primary.withValues(alpha: 0.4),
                          onChanged: (v) =>
                              setState(() => _isAvailable = v),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              context.tr('startVolunteering'),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ).animate().fadeIn(delay: 350.ms),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.textHint, fontSize: 14),
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
      );

  Widget _dropdown({
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        decoration: _inputDecoration(''),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      );
}
