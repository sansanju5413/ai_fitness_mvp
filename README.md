# AI Fitness MVP (Flutter)

This is an MVP Flutter app for an AI-powered fitness, workout, and nutrition planner.

## Features

- Firebase email/password auth
- Onboarding with basic profile and goals
- Home dashboard
- Exercise library (local JSON)
- Simple AI workout plan generator (on-device rules)
- AI chat coach (on-device rules)
- Nutrition:
  - Simple meal plan suggestion based on goal
  - Food logging with calories from local JSON
- Firestore integration for user profiles, workout sessions, and food logs

## Setup

1. Run:

   ```bash
   flutter pub get
   ```

2. Make sure you have a Flutter Android project structure (created via `flutter create`).  
   Copy the `lib/`, `assets/`, and `pubspec.yaml` from this folder into your project.

3. Firebase:

   - Use your existing `google-services.json` for Android under `android/app/google-services.json`.
   - This project already includes `firebase_options.dart` configured for the `modarbapp` project.

4. Run:

   ```bash
   flutter run
   ```

This is an MVP backbone; you can expand workouts, foods, AI backend, and UI as needed.