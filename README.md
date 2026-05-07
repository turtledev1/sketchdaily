# SketchDaily

A Flutter Android app that nudges you to sketch on paper every day. Each day it fetches a fresh reference image from Unsplash, starts a 5-minute countdown, tracks your streak, and celebrates milestone badges.

## Features

- **Daily reminder** — local notification at a configurable time (default 8:00 PM) that survives reboots.
- **Reference image from Unsplash** — rotating query (`portrait`, `still life`, `landscape`, `animal`, `hands`, `architecture`, `flower`) picked by day of year so there's variety without jarring RNG.
- **5-minute timer** with circular countdown ring; pause/resume or finish early.
- **Streak tracking** (current + longest) with per-day history stored in sqflite.
- **Milestone badges** at 3 / 7 / 14 / 30 / 60 / 100 / 180 / 365 days, with a celebration dialog + haptic when unlocked.
- **Network-required** — the app shows an offline state when unreachable rather than falling back to text prompts.

## Setup

1. **Create an Unsplash developer app** at <https://unsplash.com/oauth/applications>.
2. **Copy `.env.example` to `.env`** and fill in your keys:
   ```
   UNSPLASH_APPLICATION_ID=...
   UNSPLASH_ACCESS_KEY=...
   UNSPLASH_SECRET_KEY=...
   ```
   Only `UNSPLASH_ACCESS_KEY` is actually used by v1; the others are loaded for future OAuth flows.
   `.env` is gitignored — don't commit your keys.
3. **Install dependencies:**
   ```
   flutter pub get
   ```
4. **Run on an Android emulator or device:**
   ```
   flutter run
   ```

## Project layout

```
lib/
├── main.dart                   # Bootstrap: load .env, init HydratedBloc storage + notifications
├── app.dart                    # Root MaterialApp + theme
├── core/
│   ├── config/unsplash_config.dart
│   ├── theme/app_theme.dart
│   └── storage/database.dart   # sqflite open/migrate
└── features/
    ├── home/                   # HomePage + streak card, connectivity-aware CTA
    ├── streak/                 # HydratedBloc streak math + sqflite history repo
    ├── sketch_session/         # Timer bloc (ready/running/paused/completed) + page
    ├── prompts/                # UnsplashClient + PromptRepository
    ├── badges/                 # Badge definitions, BadgesPage grid
    ├── celebration/            # Milestone celebration dialog
    ├── notifications/          # flutter_local_notifications wrapper + daily scheduler
    └── settings/               # SettingsBloc + page (reminder time, toggle, reset)
```

## Unsplash API compliance

Per the [Unsplash API Guidelines](https://help.unsplash.com/en/articles/2511245-unsplash-api-guidelines):
- Images are **hotlinked** directly from `images.unsplash.com`, preserving the `ixid` query parameter unchanged so view-tracking works.
- The **attribution line** below the image links both the photographer and "Unsplash" with the UTM params `?utm_source=sketchdaily&utm_medium=referral`.
- The **`/photos/:id/download`** tracking endpoint is pinged when the user actually starts a session (not on image load), per the guideline that the endpoint should fire when a photo is used.

New Unsplash apps are limited to **50 requests/hour in demo mode**. At 1 session/day/user this is plenty for development.

## Testing

```
flutter analyze   # static analysis (clean)
flutter test      # unit tests for StreakBloc
```

## Android-specific notes

- `flutter_local_notifications` 17.x requires `minSdk >= 23` (set explicitly in `android/app/build.gradle.kts`).
- It also requires **core library desugaring** (for `java.time` APIs on older Androids) — enabled via `isCoreLibraryDesugaringEnabled = true` + `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` in `android/app/build.gradle.kts`.
- `AndroidManifest.xml` includes `POST_NOTIFICATIONS` (runtime-requested on Android 13+), `RECEIVE_BOOT_COMPLETED` (so reminders survive reboot), and the plugin's `ScheduledNotificationReceiver` + `ScheduledNotificationBootReceiver`.
- We use `AndroidScheduleMode.inexactAllowWhileIdle` to avoid the Android 14 `SCHEDULE_EXACT_ALARM` permission prompt. A ~minute of jitter on a habit reminder is acceptable.
