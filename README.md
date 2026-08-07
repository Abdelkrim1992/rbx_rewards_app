# 🎁 RBX Rewards App

A feature-rich, high-performance Flutter mobile & web application that enables users to earn rewards, accumulate virtual coins, engage with interactive mini-games, complete offerwall tasks, and watch video advertisements.

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Key Features](#-key-features)
- [Tech Stack & Architecture](#-tech-stack--architecture)
- [Prerequisites](#-prerequisites)
- [Environment Configuration (`.env`)](#-environment-configuration-env)
- [Running the Application](#-running-the-application)
  - [Development Mode](#development-mode)
  - [Platform-Specific Commands](#platform-specific-commands)
- [Building for Production](#-building-for-production)
- [Project Directory Structure](#-project-directory-structure)
- [Troubleshooting & Gotchas](#-troubleshooting--gotchas)
- [License](#-license)

---

## 💎 Overview

**RBX Rewards** is built with Flutter and Dart, providing a seamless cross-platform experience. Users earn points/coins by:
- Playing engaging Flame-powered mini-games (Flappy, Math Quiz, Flip Cards, Tap Tap).
- Completing tasks on leading offerwall networks (Tapjoy, Pubscale).
- Watching rewarded video ads (Google Mobile Ads / AdMob).
- Claiming daily check-in bonuses and interactive scratch cards.
- Redeeming earned coins for rewards.

---

## 🔥 Key Features

- **🎮 Mini-Games**: Built using the [Flame Engine](https://flame-engine.org/) for high-frame-rate 2D gaming experience.
- **💼 Offerwalls**: Seamless integration with **Tapjoy** and **Pubscale** SDKs for task completion rewards.
- **📺 Rewarded Ads**: Integrated with **Google Mobile Ads (AdMob)** for rewarded and interstitial ads.
- **⚡ State Management**: Clean and predictable application state managed via **Riverpod**.
- **☁️ Backend & Offline Fallback**: Powered by **Supabase** for database & authentication, with offline fallback capability when unconfigured.
- **🎯 Dynamic `.env` Configuration**: Configured securely at compile time using `--dart-define-from-file=.env`.

---

## 🛠️ Tech Stack & Architecture

- **Framework**: [Flutter](https://flutter.dev/) (SDK `>=3.0.0 <4.0.0`) & Dart
- **Game Engine**: [Flame](https://pub.dev/packages/flame)
- **Backend & Database**: [Supabase Flutter](https://pub.dev/packages/supabase_flutter)
- **State Management**: [Flutter Riverpod](https://pub.dev/packages/flutter_riverpod)
- **Local Storage**: [Hive](https://pub.dev/packages/hive_flutter) & [SharedPreferences](https://pub.dev/packages/shared_preferences)
- **Ad Networks**: [Google Mobile Ads](https://pub.dev/packages/google_mobile_ads)
- **Offerwall Networks**: [Tapjoy Offerwall](https://pub.dev/packages/tapjoy_offerwall) & [Pubscale Offerwall](https://pub.dev/packages/pubscale_offerwall_plugin)

---

## ⚙️ Prerequisites

Ensure you have the following installed on your machine:

1. **Flutter SDK**: `>=3.0.0` ([Installation Guide](https://docs.flutter.dev/get-started/install))
2. **Dart SDK**: Ships with Flutter SDK
3. **IDE**: VS Code (with Flutter extension) or Android Studio
4. **Platform Tools**:
   - **Android**: Android Studio with Android SDK & Emulator
   - **iOS**: Xcode (macOS only) for CocoaPods & iOS Simulator

Check your Flutter installation:
```bash
flutter doctor
```

---

## 🔐 Environment Configuration (`.env`)

The app uses compile-time environment variables defined in a `.env` file and passed into Flutter using `--dart-define-from-file=.env`.

Copy the provided template `.env.example` to create your local `.env` file and fill in your credentials:

```bash
# Windows Command Prompt / PowerShell / Bash:
cp .env.example .env
```

> ⚠️ **Important**: Never commit your actual `.env` file to version control. Keep `.env` listed in your `.gitignore`.

---

## 🚀 Running the Application

### Step 1: Install Dependencies

Fetch all package dependencies defined in `pubspec.yaml`:

```bash
flutter pub get
```

### Step 2: Run with `.env` Configuration

To launch the app on an active emulator or connected physical device using your `.env` file, execute:

```bash
flutter run --dart-define-from-file=.env
```

### Platform-Specific Commands

- **Android Emulator / Device**:
  ```bash
  flutter run -d android --dart-define-from-file=.env
  ```

- **iOS Simulator / Device** *(macOS only)*:
  ```bash
  flutter run -d ios --dart-define-from-file=.env
  ```

- **Chrome / Web**:
  ```bash
  flutter run -d chrome --dart-define-from-file=.env
  ```

- **Select target device interactively**:
  ```bash
  flutter devices
  flutter run -d <DEVICE_ID> --dart-define-from-file=.env
  ```

---

## 📦 Building for Production

When preparing release builds, pass `--dart-define-from-file=.env` so environment values are compiled into the production binary:

### Android APK
```bash
flutter build apk --release --dart-define-from-file=.env
```
*Output location*: `build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (for Google Play Store)
```bash
flutter build appbundle --release --dart-define-from-file=.env
```
*Output location*: `build/app/outputs/bundle/release/app-release.aab`

### iOS App Store Build *(macOS only)*
```bash
flutter build ios --release --dart-define-from-file=.env
```

### Web Production Build
```bash
flutter build web --release --dart-define-from-file=.env
```
*Output location*: `build/web/`

---

## 📁 Project Directory Structure

```text
rbx_rewards_app/
├── .env.example          # Environment variables template
├── .env                  # Environment variables (git-ignored)
├── assets/               # Images, icons, JSON files, and mini-game graphics
├── docs/                 # Documentation and architecture guides
├── lib/
│   ├── main.dart         # Entry point & Supabase / Env initialization
│   ├── business/         # Business logic (AdService, TapjoyService, PubscaleService, etc.)
│   ├── data/             # Hive storage and repositories
│   ├── presentation/     # UI Screens (Home, Spin, Games, Rewards, Profile) and Riverpod providers
│   └── widgets/          # Reusable UI widgets and dialogs
├── pubspec.yaml          # Project dependencies and asset definitions
└── README.md             # Project README
```

---

## ❓ Troubleshooting & Gotchas

1. **Environment Variables Not Loading / Empty**:
   - Ensure you use `--dart-define-from-file=.env` during `flutter run` or `flutter build`.
   - Variables loaded via `String.fromEnvironment(...)` are **compile-time constants**. Hot Reload does **not** pick up updated `.env` values; perform a full **Hot Restart** (`R`) or re-run `flutter run`.

2. **`.env` Format Issues**:
   - Avoid spaces around `=` sign in your `.env` file (e.g., use `KEY=VALUE`, not `KEY = VALUE`).
   - Do not wrap values in double quotes unless necessary.

3. **Supabase Offline Warning**:
   - If `SUPABASE_URL` or `SUPABASE_ANON_KEY` are not set in `.env`, the app logs a warning:
     `⚠️ SUPABASE_URL or SUPABASE_ANON_KEY not provided. Pass them via --dart-define or the app will run in offline mode.`
   - The app will continue to run in offline/local state mode using Hive local storage.

4. **Android Build / Gradle Issues**:
   - If dependencies fail to resolve, clean the Flutter build cache:
     ```bash
     flutter clean
     flutter pub get
     ```

---

## 📄 License

This project is proprietary software for the RBX Rewards App.
