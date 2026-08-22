# Still — Android App

> Listen-first calm focus companion. Speaks rarely with grounding nudges.

Published by **Origin Ark Studio**  
Application ID: `com.originark.still`  
Version: `1.0.0` (VersionCode `1`)

---

## 🌿 Philosophy & Features

Still is engineered for distraction-free deep work:

- **Listen-First, Speak-Rarely:** Nudges only when needed, never interrupting user flow or speech.
- **8-Minute Minimum Interval:** Hard-locked cooldown prevents repetitive or annoying interruptions.
- **Focus Session Only Mic:** Zero 24/7 background audio capture. SpeechRecognizer only runs during user-initiated active focus sessions.
- **On-Device Local Room Storage:** Tasks and session logs remain strictly on device.
- **Serene TTS Voice Presets:** Default free voice `Still Calm` plus premium subscriptions (`still_voices_monthly`, `still_voices_yearly`) for `Forest Whisper`, `Dusk Serenity`, and `Zen Harbor`.
- **Material 3 UI:** Pure dark theme with Sage `#718B5F` accent.
- **Security & Google Play Ready:** Target SDK 35, Min SDK 26, R8 code shrinking and ProGuard rules enabled, `usesCleartextTraffic="false"`, no hardcoded secrets, minimal permissions.

---

## 📱 Navigation & Screens

1. **Home / Focus Session:** Displays active intention task, serene pulse animation, session timer, focus state (listening vs talking), and start/stop session controls.
2. **Tasks:** Add, select active intention, complete, or delete tasks backed by local Room database.
3. **Voices + Subscribe:** Preview and choose TTS presets; Google Play Billing subscription integration.
4. **Settings:** Microphone permission management, privacy commitment breakdown, restore purchases, and app details.

---

## 🛠️ Build and Validation

### Prerequisites
- JDK 21
- Android SDK Platform 35 & Build-Tools 35.0.0 (`minSdk 26`, `targetSdk 35`)

### Commands (from `still/`)
```bash
# Run unit tests (Nudge interval, listen-vs-talk, billing state, repository)
./gradlew testDebugUnitTest

# Assemble debug APK
./gradlew :app:assembleDebug

# Assemble release APK / Bundle
./gradlew :app:assembleRelease
```

---

## 📂 Project Structure
```
still/
├── app/
│   ├── src/main/
│   │   ├── AndroidManifest.xml
│   │   ├── java/com/originark/still/
│   │   │   ├── MainActivity.kt
│   │   │   ├── StillApplication.kt
│   │   │   ├── data/
│   │   │   │   ├── local/ (TaskDao, SessionLogDao, StillDatabase)
│   │   │   │   ├── model/ (Task, SessionLog, VoicePreset)
│   │   │   │   └── repository/ (StillRepository)
│   │   │   ├── domain/
│   │   │   │   ├── audio/ (AndroidSpeechManager, SpeechContracts)
│   │   │   │   ├── billing/ (BillingModels, PlayBillingManager)
│   │   │   │   ├── nudge/ (NudgeEngine, FocusState)
│   │   │   │   └── tts/ (StillTtsEngine)
│   │   │   └── ui/
│   │   │       ├── StillApp.kt
│   │   │       ├── screens/ (HomeScreen, TasksScreen, VoicesScreen, SettingsScreen)
│   │   │       └── theme/ (Color, Type, Theme)
│   │   └── res/ (Adaptive icon, themes, strings)
│   ├── src/test/ (NudgeEngineTest, BillingStateTest, StillRepositoryTest)
│   ├── proguard-rules.pro
│   └── build.gradle.kts
├── docs/
│   └── privacy.md
├── store/
│   ├── listing.md
│   └── play-console.md
├── product/
│   └── specification.md
├── build.gradle.kts
├── settings.gradle.kts
└── README.md
```
