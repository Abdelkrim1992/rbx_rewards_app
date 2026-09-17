# Phase 5: Appropriate Sounds & Smart Notifications
## Implementation Specification & Task Breakdown

---

## 🎯 Phase Objective
Enhance the user experience and sensory dopamine loops by adding **appropriate, high-satisfaction game sound effects (SFX)**, a **flying coin particle animation with rolling counter**, and an **on-device smart notification engine** to maximize Day-1, Day-7, and Day-30 user retention.

---

## 🎵 Section 1: Sound Effects (SFX) Specification

### Acoustic Profiles (Professional Mobile Game Sound Design)
Every sound must be clean, crisp, and high-satisfaction (never harsh, annoying, or low-quality):

| Sound File | Acoustic Profile | Duration | Trigger Location |
| :--- | :--- | :---: | :--- |
| **`coin_collect.wav`** | Two-tone crystal chime: **B5 (988 Hz) $\rightarrow$ E6 (1319 Hz)** with 120ms exponential decay and bright 3.9kHz overtone. | ~0.4s | As flying coins hit the header balance counter. |
| **`jackpot_win.wav`** | Ascending triumphant major triad: **C5 (523Hz) $\rightarrow$ E5 (659Hz) $\rightarrow$ G5 (783Hz) $\rightarrow$ C6 (1046Hz)** with shimmering bell harmonics. | ~1.2s | Claiming 2x double ad bonus, winning wheel jackpot, opening Mega Chest. |
| **`wheel_tick.wav`** | Short, dry acoustic mechanical transient at **1800 Hz** with rapid dampening. | ~0.02s | Triggered on each peg the Lucky Wheel passes while spinning. |
| **`chest_open.wav`** | Heavy mechanical latch click (150Hz) rising into a magical resonant chord (**F#5 + A#5 + C#6**). | ~0.8s | Opening the Mystery Chest or Daily Quests chest. |
| **`button_tap.wav`** | Soft, organic wooden tap (**450 Hz $\rightarrow$ 250 Hz**). | ~0.04s | Claim buttons, tab navigation, dialog actions. |
| **`bubble_pop.wav`** | Smooth downward pitch glide (**850 Hz $\rightarrow$ 180 Hz**). | ~0.05s | Tapping target bubbles in Tap Tap and flipping cards in Flip Card game. |
| **`scratch_rustle.wav`**| Soft textured paper scratch sound. | Loop | Finger movement on the scratch card canvas. |

### Technical Sound Architecture
* **Package:** `audioplayers: ^6.1.0`
* **Preloading & Zero-Latency:** Preload sound buffers into an in-memory `AudioPool` / cache during app startup.
* **Preferences Sync:** Reads `pref_sound_enabled` directly from `settings_screen.dart`. If sound is toggled off, playback calls return immediately.

---

## ✨ Section 2: Flying Coin Animation & Rolling Counter

When coins are awarded (game completion, chest claim, streak claim, wheel spin):

```
[ Claim Button / Dialog ]
           │
           ▼
[ 1. Particle Burst ] ──► 8 to 12 gold coin sprites scatter in a radial burst (radius: 40–60px)
           │
           ▼
[ 2. Curved Flight ]  ──► Coins fly along an animated Bezier arc towards the top-right Balance badge
           │
           ▼
[ 3. Impact & Chime ] ──► Header badge bounces (Scale 1.0 ➔ 1.25 ➔ 1.0)
                          `coin_collect.wav` plays with subtle haptic vibration
                          Balance text smoothly counts up: 4,500 ➔ 4,510 ➔ 4,520 ... ➔ 4,550
```

### Components to Build:
1. **`CoinFlyOverlay` (`lib/widgets/coin_fly_overlay.dart`):**
   * Global static method: `CoinFlyOverlay.spawn(BuildContext context, {required Offset fromPosition, int coinCount = 10, VoidCallback? onComplete})`.
   * Renders in the app's top-level `Overlay` so it is visible across modal sheets, dialogs, and navigation transitions.
2. **Animated Counter in `AppHeader` (`lib/widgets/app_header.dart`):**
   * Wrap the balance display in a `TweenAnimationBuilder<int>` that smoothly animates the integer value over 600ms.
   * Add a `ScaleTransition` pulse triggered whenever a coin arrives.

---

## 🔔 Section 3: Smart Local Notifications Engine

Runs **100% on-device** using `flutter_local_notifications` (zero server cost, works offline).

### The 3 Core Automated Return Loops:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   THE 3 RETENTION NOTIFICATION HOOKS                   │
├────────────────────────────────────────────────────────────────────────┤
│ 1. The Mystery Chest Ready Alert                                       │
│    ⏰ Trigger : Scheduled exactly 3 hours after user opens a chest     │
│    💬 Title   : "🎁 Your Mystery Chest is Ready!"                      │
│    💬 Body    : "The cooldown has ended. Tap to open and claim coins!" │
├────────────────────────────────────────────────────────────────────────┤
│ 2. The Daily Quests Midday Reminder                                    │
│    ⏰ Trigger : Daily at 1:00 PM local time                            │
│    💬 Title   : "🎯 3 New Quests are Live!"                            │
│    💬 Body    : "Complete your quick daily tasks to claim easy points."│
├────────────────────────────────────────────────────────────────────────┤
│ 3. The Streak Protector (Loss Aversion)                                │
│    ⏰ Trigger : Daily at 8:00 PM (canceled if user logged in today)   │
│    💬 Title   : "🔥 Protect Your Daily Streak!"                        │
│    💬 Body    : "Don't lose your streak bonus! Claim your reward now." │
└────────────────────────────────────────────────────────────────────────┘
```

### Permission Strategy:
* **Android 13+:** Request `POST_NOTIFICATIONS` runtime permission.
* **iOS:** Request alert, badge, and sound permissions.
* **Timing:** Prompt for notification permission **only after the user claims their first chest or spin** (when they are engaged), rather than cold-prompting on initial app boot.
* **Settings Toggle:** Linked directly to `pref_notifications_enabled` in `settings_screen.dart`.

---

## 📋 Actionable Tasks

### Task 5.1: Audio Engine & Asset Generation
* **Files:**
  * `pubspec.yaml`
  * `assets/sounds/`
  * `lib/business/sound_service.dart`
* **Sub-tasks:**
  - [ ] Add `audioplayers: ^6.1.0` to `pubspec.yaml` dependencies.
  - [ ] Register `assets/sounds/` in `pubspec.yaml` assets list.
  - [ ] Generate/add the 6 core 16-bit 44.1kHz `.wav` sound files in `assets/sounds/`.
  - [ ] Implement `SoundService` with preloaded audio pools for `playCoin()`, `playJackpot()`, `playWheelTick()`, `playChestOpen()`, `playButton()`, and `playBubble()`.
  - [ ] Respect `pref_sound_enabled` SharedPreferences toggle.

### Task 5.2: Flying Coin Animation & Rolling Counter
* **Files:**
  * `lib/widgets/coin_fly_overlay.dart` (New Widget)
  * `lib/widgets/app_header.dart`
* **Sub-tasks:**
  - [ ] Build `CoinFlyOverlay` with particle scatter and Bezier curve trajectory to the top-right header balance icon.
  - [ ] Implement rolling counter (`TweenAnimationBuilder<int>`) in `AppHeader` with scale pulse animation.
  - [ ] Wire `CoinFlyOverlay` to trigger `SoundService.playCoin()` on each particle arrival.
  - [ ] Connect `CoinFlyOverlay` to reward claim dialogs (`reward_claim_dialog.dart`, `two_tier_reward_dialog.dart`).

### Task 5.3: In-App Audio Hookups Across Screens
* **Files:**
  * `lib/presentation/screens/spin_screen.dart`
  * `lib/presentation/screens/chest_screen.dart`
  * `lib/presentation/screens/tap_tap_game_screen.dart`
  * `lib/presentation/screens/scratch_card_screen.dart`
* **Sub-tasks:**
  - [ ] In `spin_screen.dart`: Trigger `SoundService.playWheelTick()` during wheel rotation, and `playJackpot()` on win.
  - [ ] In `chest_screen.dart`: Trigger `SoundService.playChestOpen()` when opening a chest.
  - [ ] In `tap_tap_game_screen.dart`: Trigger `SoundService.playBubble()` on bubble taps.
  - [ ] In `scratch_card_screen.dart`: Trigger `SoundService.playScratch()` during scratch gestures.

### Task 5.4: Notification Engine Setup & Scheduling
* **Files:**
  * `pubspec.yaml`
  * `lib/business/notification_service.dart` (New Service)
  * `lib/presentation/screens/settings_screen.dart`
* **Sub-tasks:**
  - [ ] Add `flutter_local_notifications: ^18.0.0` to `pubspec.yaml`.
  - [ ] Configure Android notification channels (`rewards_channel`, high priority).
  - [ ] Build `NotificationService` with methods:
    - `scheduleChestReady(DateTime triggerAt)`
    - `scheduleStreakReminder()`
    - `scheduleDailyQuestsReminder()`
    - `cancelAll()`
  - [ ] Hook `scheduleChestReady` into `chest_screen.dart` when a chest is opened.
  - [ ] Hook `pref_notifications_enabled` switch in `settings_screen.dart` to enable/disable scheduling.

---

## 🎯 Phase 5 Definition of Done (DoD)
1. Every claim action triggers flying gold coins toward the balance header with audio chimes and counter rolling.
2. Lucky Wheel ticks realistically during rotation, and chests creak open with magical audio.
3. Sound and notification settings in `settings_screen.dart` instantly enable or mute all audio and notifications.
4. Mystery Chest scheduling triggers on-device notifications after 3 hours, and daily streak reminders alert users at 8:00 PM.
