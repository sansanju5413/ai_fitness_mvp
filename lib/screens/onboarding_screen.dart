import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/fitness_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  int _age = 21;
  String _gender = 'male';
  double _height = 170;
  double _weight = 65;
  String _goal = 'fat_loss';
  String _activity = 'moderate';
  String? _error;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.firebaseUser;
    final textTheme = Theme.of(context).textTheme;

    if (user == null) {
      return FitnessPage(
        child: Center(
          child: SelectableText.rich(
            const TextSpan(
              text: 'Not logged in',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      );
    }

    return FitnessPage(
      appBar: AppBar(
        title: const Text('Let’s personalize your plan'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We’ll adjust workouts, nutrition, and recovery to your data.',
              style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 18),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Basics',
                    subtitle: 'So we can address you right.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Name'),
                    onSaved: (v) => _name = v!.trim(),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Age'),
                    keyboardType: TextInputType.number,
                    onSaved: (v) => _age = int.tryParse(v ?? '') ?? 21,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Gender'),
                    value: _gender,
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => _gender = v ?? 'male'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Body metrics',
                    subtitle: 'We use this to scale workouts.',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration:
                              const InputDecoration(labelText: 'Height (cm)'),
                          keyboardType: TextInputType.number,
                          onSaved: (v) =>
                              _height = double.tryParse(v ?? '') ?? 170,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          decoration:
                              const InputDecoration(labelText: 'Weight (kg)'),
                          keyboardType: TextInputType.number,
                          onSaved: (v) =>
                              _weight = double.tryParse(v ?? '') ?? 65,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Goal'),
                    value: _goal,
                    items: const [
                      DropdownMenuItem(
                        value: 'fat_loss',
                        child: Text('Fat Loss'),
                      ),
                      DropdownMenuItem(
                        value: 'muscle_gain',
                        child: Text('Muscle Gain'),
                      ),
                      DropdownMenuItem(
                        value: 'general',
                        child: Text('General Fitness'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _goal = v ?? 'fat_loss'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration:
                        const InputDecoration(labelText: 'Activity level'),
                    value: _activity,
                    items: const [
                      DropdownMenuItem(
                        value: 'sedentary',
                        child: Text('Sedentary'),
                      ),
                      DropdownMenuItem(
                        value: 'moderate',
                        child: Text('Moderate'),
                      ),
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('Active'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _activity = v ?? 'moderate'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Preview',
                    subtitle: 'Your experience will adapt in real time.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _Chip(text: 'AI workout blocks'),
                      _Chip(text: 'Calorie targets'),
                      _Chip(text: 'Meal swaps'),
                      _Chip(text: 'Recovery nudges'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              SelectableText.rich(
                TextSpan(
                  text: 'Error: ',
                  style: const TextStyle(color: Colors.redAccent),
                  children: [
                    TextSpan(
                      text: _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('Save and continue'),
                onPressed: appState.loading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        _formKey.currentState!.save();
                        final nav = Navigator.of(context);
                        final profile = AppUser(
                          uid: user.uid,
                          email: user.email ?? '',
                          name: _name,
                          age: _age,
                          gender: _gender,
                          heightCm: _height,
                          weightKg: _weight,
                          goal: _goal,
                          activityLevel: _activity,
                        );
                        try {
                          await appState.updateProfile(profile);
                          if (mounted) {
                            nav.pushReplacementNamed('/home');
                          }
                        } catch (e) {
                          setState(() => _error = e.toString());
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;

  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Colors.white70),
      ),
    );
  }
}