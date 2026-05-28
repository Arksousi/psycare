import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../data/models/volunteer_model.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/volunteer_provider.dart';

class BrowseVolunteersScreen extends ConsumerStatefulWidget {
  const BrowseVolunteersScreen({super.key});

  @override
  ConsumerState<BrowseVolunteersScreen> createState() =>
      _BrowseVolunteersScreenState();
}

class _BrowseVolunteersScreenState
    extends ConsumerState<BrowseVolunteersScreen> {
  String _filter = 'All';
  bool _bannerDismissed = true;

  static const _filters = [
    'All',
    'Psychology',
    'Medicine',
    'Social Work',
    'Nursing',
  ];

  @override
  void initState() {
    super.initState();
    _checkBanner();
  }

  Future<void> _checkBanner() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool('volunteerInfoDismissed') ?? false;
    if (mounted) setState(() => _bannerDismissed = dismissed);
  }

  Future<void> _dismissBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('volunteerInfoDismissed', true);
    if (mounted) setState(() => _bannerDismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    final volunteersAsync = ref.watch(availableVolunteersProvider);
    final patientId = ref.watch(currentUserProvider)?.uid ?? '';
    final connectionsAsync = ref.watch(patientAllConnectionsProvider(patientId));
    final connectionMap = {
      for (final c in connectionsAsync.valueOrNull ?? []) c.volunteerId: c.status
    };

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
                          context.tr('findCompanion'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          context.tr('findCompanionSub'),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Info banner
              if (!_bannerDismissed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('volunteerInfoBanner'),
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.5),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _dismissBanner,
                          child: Text(
                            context.tr('gotIt'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (!_bannerDismissed) const SizedBox(height: 12),

              // Filter chips
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    for (final f in _filters) ...[
                      if (f != _filters.first) const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _filter = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _filter == f
                                ? AppColors.primary
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _filter == f
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _filter == f
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Volunteer list
              Expanded(
                child: volunteersAsync.when(
                  data: (all) {
                    final filtered = all
                        .where((v) =>
                            _filter == 'All' || v.specialization == _filter)
                        .toList();

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
                              context.tr('noVolunteersFound'),
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500),
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
                        final v = filtered[i];
                        return _VolunteerCard(
                          volunteer: v,
                          connStatus: connectionMap[v.volunteerId],
                          onViewProfile: () => Navigator.pushNamed(
                            context,
                            AppRoutes.volunteerProfile,
                            arguments: v,
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary)),
                  error: (e, _) => Center(
                      child: Text(e.toString(),
                          style: const TextStyle(
                              color: AppColors.textSecondary))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VolunteerCard extends StatelessWidget {
  final VolunteerModel volunteer;
  final String? connStatus;
  final VoidCallback onViewProfile;

  const _VolunteerCard({
    required this.volunteer,
    required this.onViewProfile,
    this.connStatus,
  });

  @override
  Widget build(BuildContext context) {
    final bioPreview = volunteer.bio.length > 80
        ? '${volunteer.bio.substring(0, 80)}…'
        : volunteer.bio;

    final isActive = connStatus == 'active';
    final isPending = connStatus == 'pending';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar + name row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: volunteer.profilePhoto.isNotEmpty
                    ? NetworkImage(volunteer.profilePhoto)
                    : null,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: volunteer.profilePhoto.isEmpty
                    ? Text(
                        _safeInitial(volunteer.name),
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      volunteer.name.isEmpty ? '—' : volunteer.name,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${volunteer.specialization} • ${volunteer.university}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (volunteer.yearOfStudy.isNotEmpty)
                      Text(
                        volunteer.yearOfStudy,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textHint),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Bio
          if (bioPreview.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              bioPreview,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ],

          const SizedBox(height: 10),

          // Stats + action — split into two rows to avoid Spacer issues
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Stats
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFF59E0B), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    volunteer.ratingCount > 0
                        ? '${volunteer.rating.toStringAsFixed(1)} (${volunteer.ratingCount})'
                        : 'New',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.access_time_rounded,
                      color: AppColors.textHint, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${volunteer.volunteerHours} hrs',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textHint),
                  ),
                ],
              ),

              // Action
              if (isActive)
                _statusChip(context.tr('connected'), AppColors.success)
              else if (isPending)
                _statusChip(context.tr('requestSent'), AppColors.primary)
              else
                GestureDetector(
                  onTap: onViewProfile,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      context.tr('viewProfile'),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _safeInitial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  Widget _statusChip(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color)),
      );
}
