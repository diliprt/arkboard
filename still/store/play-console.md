# Google Play Console Setup & Checklist — Still

## 1. App Configuration & Identification
- **App Name:** Still
- **Default Language:** English (United States) — `en-US`
- **Application ID:** `com.originark.still`
- **Category:** Productivity
- **Tags:** Focus, Productivity, Self-Care

## 2. App Content & Declarations
- **Privacy Policy URL:** Link to `still/docs/privacy.md` (or hosted GitHub Pages URL).
- **Target Audience:** 18 and over / All ages (Content Rating: Everyone / 3+).
- **Data Safety Declaration:**
  - **Data collection:** No personal data collected or shared.
  - **Audio Data:** Ephemeral on-device audio parsing only during active user-started sessions. Not stored on device, not transmitted off-device.
  - **Data Security:** Encrypted in transit (HTTPS/no cleartext) and all app data is stored on local SQLite/Room database.
  - **Account Creation:** None required.
- **Microphone Declaration:**
  - Permission `RECORD_AUDIO` is used strictly within foreground user-initiated Focus Sessions for SpeechRecognizer speech-vs-silence detection.

## 3. Play Billing Subscriptions Configuration
Navigate to **Monetize > Subscriptions** in Google Play Console and create:

1. **Base Product ID:** `still_voices_monthly`
   - **Name:** Still Voices Monthly
   - **Description:** Monthly subscription unlocking all premium serene TTS voice presets.
   - **Default Base Plan:** Auto-renewing, Monthly billing, $2.99 USD.

2. **Base Product ID:** `still_voices_yearly`
   - **Name:** Still Voices Yearly
   - **Description:** Annual subscription unlocking all present and future serene TTS voice presets.
   - **Default Base Plan:** Auto-renewing, Yearly billing, $19.99 USD.

## 4. Release Signing & Build
- **Play App Signing:** Opt into Google Play App Signing.
- **Upload Key:** Generate release keystore:
  ```bash
  keytool -genkey -v -keystore still-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias still
  ```
- **Bundle generation:**
  ```bash
  cd still && ./gradlew bundleRelease
  ```
  Artifact location: `still/app/build/outputs/bundle/release/app-release.aab`

## 5. Store Assets Required
- **App Icon:** 512 x 512 PNG (provided adaptive vector in app res).
- **Feature Graphic:** 1024 x 500 JPG or 24-bit PNG.
- **Phone Screenshots:** Minimum 2 screenshots (1080x1920 or 1080x2400) representing Home/session, Tasks, Voices, and Settings.
