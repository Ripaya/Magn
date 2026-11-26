# Magn

A minimalist Kinetic Focus Dial & Pomodoro app for Android (`magn.ion`) built around a 3-layer rotating mechanical dial.

## Alpha CI & Consistent Release Signing

Every push to `main` (or manual workflow run) triggers `.github/workflows/alpha-release.yml`:
1. Runs `flutter analyze` and `flutter test`.
2. Auto-increments version and build number starting at `0.1.0-a` (Build `1`) -> `0.1.1-a` (Build `2`) -> `0.1.2-a` (Build `3`), etc.
3. Signs the release APK with persistent credentials and publishes it under the `alpha` GitHub Release tag.

### One-Time Signing Setup (Required for Consistent Alpha Updates)
Run the helper script once locally to generate your release keystore (gitignored):
```bash
chmod +x scripts/generate_keystore.sh
./scripts/generate_keystore.sh
```
Then add the 4 printed values to **GitHub Repository Settings → Secrets and variables → Actions**:
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
