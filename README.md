# Wi-Fi Password Guide

A simple, clean Flutter mobile app that guides users through finding saved Wi-Fi passwords on a Windows PC using the classic `netsh` commands.

The app **does not** run any commands itself (mobile devices cannot execute Windows `netsh`). It only shows the correct commands with one-tap **Copy** buttons so the user can paste them into Command Prompt on their PC.

## Features

- 4 clear interactive steps
- One-tap copy for every command
- Editable network name field that automatically builds the correct `netsh` command
- Remembers the last network name you typed (SharedPreferences)
- Dark / light mode support (follows system)
- Material 3 design
- Offline – no internet required

## Commands used

```bash
# List all saved profiles
netsh wlan show profiles

# Show password for a specific network
netsh wlan show profile name="YourNetworkName" key=clear
```

## Download the app (Android)

Get the latest APK from **[Releases → Latest](https://github.com/m9r1u5/wifi_password_guide/releases/latest)** and open `WiFi-Password-Guide.apk` on your phone.

The APK is built automatically by GitHub Actions (`.github/workflows/build-apk.yml`) every time something is pushed to `main`. You can also run it manually from the **Actions** tab → *Build Android APK* → **Run workflow**.

## Getting Started

### Prerequisites

- Flutter SDK (3.0 or higher)
- Android Studio / VS Code with Flutter extension
- A physical device or emulator

### Run the app

```bash
# Clone the repository
git clone https://github.com/m9r1u5/wifi_password_guide.git
cd wifi_password_guide

# Get dependencies
flutter pub get

# Run on connected device / emulator
flutter run
```

### Build release APK (Android)

```bash
flutter build apk --release
```

The APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

### Build for iOS

```bash
flutter build ios
```

(Requires a Mac and Xcode)

## Project Structure

```
lib/
  main.dart          # Entire app (single-file for simplicity)
pubspec.yaml
README.md
```

## How to publish to your GitHub repository

1. Create a new repository on GitHub (e.g. `wifi_password_guide`)
2. In the project folder run:

```bash
git init
git add .
git commit -m "Initial commit - Wi-Fi Password Guide app"
git branch -M main
git remote add origin https://github.com/m9r1u5/wifi_password_guide.git
git push -u origin main
```

Replace `m9r1u5` with your actual GitHub username.

## License

MIT – feel free to use and modify.
