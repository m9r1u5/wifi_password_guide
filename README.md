# Wi-Fi Password Guide

A phone-only Flutter app that shows the password of a Wi-Fi network your phone has saved. No PC needed.

Android does not allow apps to read saved Wi-Fi passwords directly. It does put the password inside the
**Share Wi-Fi QR code** (Settings → Wi-Fi → network → Share / QR code). This app reads that QR code and shows
the network name and password in plain text.

## Download (Android)

Get the latest APK from **[Releases → Latest](https://github.com/m9r1u5/wifi_password_guide/releases/latest)**
and open `WiFi-Password-Guide.apk` on your phone. Needs Android 7.0 or newer.

## Features

- **From screenshot:** pick a screenshot of the Wi-Fi Share QR code and the password is shown
- **Scan camera:** scan the QR on another phone's screen or on a router sticker
- **Saved list:** keep found passwords with show/hide and copy buttons
- **How-to screen:** steps for Samsung, other Android phones and iPhone, plus a button to open Wi-Fi settings
- Works fully offline; nothing leaves the phone
- Light/dark mode follows the system

## How it works

Wi-Fi QR codes use the standard format:

```
WIFI:T:WPA;S:NetworkName;P:Password;H:false;;
```

The app decodes the QR (Google ML Kit via `mobile_scanner`, bundled, offline) and parses that text.

## Build

The APK is built automatically by GitHub Actions (`.github/workflows/build-apk.yml`) on every push to `main`
and published as a GitHub Release. You can also run it from the **Actions** tab → *Build Android APK* →
**Run workflow**.

The repo holds only `lib/`, `pubspec.yaml` and this README. The workflow generates the Android project files
with `flutter create` during the build.

Local build:

```bash
git clone https://github.com/m9r1u5/wifi_password_guide.git
cd wifi_password_guide
flutter create --platforms android .
flutter pub get
flutter build apk --release
```

## License

MIT
