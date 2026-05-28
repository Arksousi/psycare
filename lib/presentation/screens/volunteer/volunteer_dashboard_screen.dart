import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../data/models/volunteer_connection_model.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/volunteer_provider.dart';

class VolunteerDashboardScreen extends ConsumerWidget {
  const VolunteerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final volunteerAsync = ref.watch(currentVolunteerProvider);
    final connectionsAsync =
        ref.watch(volunteerConnectionsProvider(user?.uid ?? ''));

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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${context.tr('hello')}, 🎓',
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              volunteerAsync.valueOrNull?.name ??
                                  user?.name ??
                                  '',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              context.tr('volunteerThanks'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Availability toggle + settings
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          volunteerAsync.when(
                            data: (v) => v == null
                                ? const SizedBox.shrink()
                                : _AvailabilityToggle(
                                    isAvailable: v.isAvailable,
                                    volunteerId: v.volunteerId,
                                  ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pushNamed(
                                context, AppRoutes.settings),
                            icon: const Icon(Icons.settings_outlined,
                                color: AppColors.textSecondary, size: 22),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Stats row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: volunteerAsync.when(
                    data: (v) => v == null
                        ? const SizedBox.shrink()
                        : Row(
                            children: [
                              Expanded(
                                  child: _StatCard(
                                icon: Icons.access_time_rounded,
                                value: '${v.volunteerHours}',
                                label: context.tr('volunteerHrs'),
                                color: AppColors.primary,
                              )),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _StatCard(
                                icon: Icons.people_rounded,
                                value: '${v.connectedPatients.length}',
                                label: context.tr('patients'),
                                color: AppColors.accent,
                              )),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _StatCard(
                                icon: Icons.star_rounded,
                                value: v.ratingCount > 0
                                    ? v.rating.toStringAsFixed(1)
                                    : '—',
                                label: context.tr('rating'),
                                color: const Color(0xFFF59E0B),
                              )),
                            ],
                          ),
                    loading: () => const _StatsSkeletonRow(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Action buttons
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _ActionButton(
                        label: context.tr('browsePatients'),
                        icon: Icons.person_search_rounded,
                        color: AppColors.accent,
                        onTap: () => Navigator.pushNamed(
                            context, AppRoutes.browsePatients),
                      ),
                      const SizedBox(height: 12),
                      _ActionButton(
                        label: context.tr('myConnections'),
                        icon: Icons.favorite_rounded,
                        color: AppColors.primary,
                        onTap: () => Navigator.pushNamed(
                            context, AppRoutes.myConnections),
                      ),
                      const SizedBox(height: 12),
                      _ActionButton(
                        label: context.tr('editProfile'),
                        icon: Icons.edit_rounded,
                        color: AppColors.textSecondary,
                        outlined: true,
                        onTap: () => Navigator.pushNamed(
                            context, AppRoutes.volunteerProfileSetup),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Incoming requests (patient-initiated pending)
              _IncomingRequestsSection(volunteerId: user?.uid ?? ''),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Active connections list
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    context.tr('activeConnections'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ).animate().fadeIn(delay: 250.ms),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              connectionsAsync.when(
                data: (connections) {
                  final active = connections
                      .where((c) => c.status == 'active')
                      .toList();
                  if (active.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            context.tr('noActiveConnections'),
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14),
                          ),
                        ),
                      ).animate().fadeIn(delay: 300.ms),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: _ConnectionTile(
                          connection: active[i],
                          volunteerId: user?.uid ?? '',
                        ),
                      ),
                      childCount: active.length,
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary))),
                error: (_, __) =>
                    const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailabilityToggle extends ConsumerWidget {
  final bool isAvailable;
  final String volunteerId;
  const _AvailabilityToggle(
      {required this.isAvailable, required this.volunteerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Switch(
          value: isAvailable,
          activeThumbColor: AppColors.primary,
          activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
          onChanged: (v) => ref
              .read(volunteerServiceProvider)
              .updateAvailability(volunteerId, v),
        ),
        Text(
          isAvailable
              ? context.tr('available')
              : context.tr('unavailable'),
          style: TextStyle(
            fontSize: 10,
            color: isAvailable ? AppColors.success : AppColors.textHint,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatCard(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _StatsSkeletonRow extends StatelessWidget {
  const _StatsSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
          3,
          (i) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(left: i > 0 ? 10 : 0),
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              )),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: outlined ? AppColors.surface : color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: outlined ? AppColors.border : Colors.transparent),
          boxShadow: outlined
              ? []
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: outlined ? color : Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: outlined ? color : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  final VolunteerConnectionModel connection;
  final String volunteerId;
  const _ConnectionTile(
      {required this.connection, required this.volunteerId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              connection.patientFirstName.isNotEmpty
                  ? connection.patientFirstName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              connection.patientFirstName,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.volunteerChat,
              arguments: {
                'sessionId': connection.chatId,
                'volunteerId': volunteerId,
                'connectionId': connection.connectionId,
                'isVolunteer': true,
              },
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                context.tr('openChat'),
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

class _IncomingRequestsSection extends ConsumerStatefulWidget {
  final String volunteerId;
  const _IncomingRequestsSection({required this.volunteerId});

  @override
  ConsumerState<_IncomingRequestsSection> createState() =>
      _IncomingRequestsSectionState();
}

class _IncomingRequestsSectionState
    extends ConsumerState<_IncomingRequestsSection> {
  final _busy = <String, bool>{};

  Future<void> _accept(String connectionId) async {
    setState(() => _busy[connectionId] = true);
    try {
      final chatId = await ref
          .read(volunteerServiceProvider)
          .acceptConnectionRequest(connectionId);
      if (mounted) {
        Navigator.pushNamed(
          context,
          AppRoutes.volunteerChat,
          arguments: {
            'sessionId': chatId,
            'volunteerId': widget.volunteerId,
            'connectionId': connectionId,
            'isVolunteer': true,
          },
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(connectionId));
    }
  }

  Future<void> _decline(String connectionId) async {
    setState(() => _busy[connectionId] = true);
    try {
      await ref
          .read(volunteerServiceProvider)
          .declineConnectionRequest(connectionId);
    } finally {
      if (mounted) setState(() => _busy.remove(connectionId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync =
        ref.watch(volunteerIncomingRequestsProvider(widget.volunteerId));

    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('incomingRequests'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ...requests.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.primary
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor:
                                  AppColors.accent.withValues(alpha: 0.15),
                              child: Text(
                                r.patientFirstName.isNotEmpty
                                    ? r.patientFirstName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                r.patientFirstName,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary),
                              ),
                            ),
                            if (_busy[r.connectionId] == true)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary),
                              )
                            else ...[
                              GestureDetector(
                                onTap: () => _decline(r.connectionId),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  child: Text(
                                    context.tr('declineRequest'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _accept(r.connectionId),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    context.tr('acceptRequest'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )),
              ],
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            'Request load error: $e',
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
