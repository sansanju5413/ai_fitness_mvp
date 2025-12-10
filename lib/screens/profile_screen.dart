import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/fitness_page.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final profile = appState.profile;
    final textTheme = Theme.of(context).textTheme;

    return FitnessPage(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: profile == null
          ? Center(
              child: SelectableText.rich(
                const TextSpan(
                  text: 'No profile data',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name ?? 'Athlete',
                        style: textTheme.headlineMedium
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        profile.email,
                        style: textTheme.bodyMedium
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const SectionHeader(
                  title: 'Vitals',
                  subtitle: 'Used to scale your program.',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoChip(
                      label: 'Age',
                      value: profile.age?.toString() ?? '—',
                    ),
                    _InfoChip(
                      label: 'Gender',
                      value: profile.gender ?? '—',
                    ),
                    _InfoChip(
                      label: 'Height',
                      value: profile.heightCm != null
                          ? '${profile.heightCm} cm'
                          : '—',
                    ),
                    _InfoChip(
                      label: 'Weight',
                      value: profile.weightKg != null
                          ? '${profile.weightKg} kg'
                          : '—',
                    ),
                    _InfoChip(
                      label: 'Goal',
                      value: profile.goal ?? '—',
                    ),
                    _InfoChip(
                      label: 'Activity',
                      value: profile.activityLevel ?? '—',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/onboarding');
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Update profile'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await appState.signOut();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (_) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}