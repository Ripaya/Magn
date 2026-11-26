# Magn

A minimalist Kinetic Focus Dial & Pomodoro app for Android (`magn.ion`) built around a 3-layer rotating mechanical dial.

## Alpha CI & Consistent Release Signing

Every push to `main` (or manual workflow run) triggers `.github/workflows/alpha-release.yml`:
1. Runs `flutter analyze` and `flutter test`.
2. Auto-increments version and build number starting at `0.1.0-a` (Build `1`) -> `0.1.1-a` (Build `2`) -> `0.1.2-a` (Build `3`), etc.
3. Signs the release APK with persistent credentials and publishes it under the `alpha` GitHub Release tag.

### Signing Configuration
Release builds use GitHub Actions repository secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD`) to configure `android/app/magn-alpha.jks` and `android/key.properties` during CI runs. Local builds read `android/key.properties` when present (gitignored).
