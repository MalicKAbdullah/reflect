<div align="center">

# 📓 Reflect

### A private space to think.

An encrypted journal locked with your PIN or fingerprint — calm, searchable, and completely yours.

![License](https://img.shields.io/badge/License-MIT-7C3AED?style=flat-square)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-7C3AED?style=flat-square)
![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-027DFD?style=flat-square&logo=flutter)
![Privacy](https://img.shields.io/badge/Data-Offline%20%26%20Encrypted-34D399?style=flat-square)
![Trackers](https://img.shields.io/badge/Trackers-0-34D399?style=flat-square)

</div>

> ### 🔒 Private by design
> Reflect works **completely offline**. Every entry is **encrypted and unlocked only by you** — with a PIN or your fingerprint/face. No account, no servers, no analytics. Your thoughts never leave your device.

Reflect is a quiet place to write, remember, and notice patterns over time — built so you can be completely honest, because nobody else can ever read it.

## ✨ Features

**Write freely**
- Simple, distraction-free entries with an optional title and mood
- **Markdown-lite** formatting — bold, italics, and bullet lists
- Gentle daily reminder and rotating writing prompts

**Remember more**
- **Encrypted photo attachments** from your gallery or camera
- **Full-text search** across everything you've written
- Calendar view, tags, and an **"On This Day"** look back

**See your patterns**
- Mood trends, distributions, and writing streaks
- Writing goals to build the habit
- Export a beautiful **Year-in-Review PDF**

**Locked down**
- **PIN + optional biometric unlock**, with auto-lock when you leave the app
- **Encrypted backup & restore** — a passphrase-protected file you control

## 🔒 Privacy & Security

Reflect has the strongest lock in the suite, because a journal demands it:

- **Offline-only.** No network code, nothing to leak.
- **Unlocked by you.** Your data key is derived from your PIN with **Argon2id** (a slow, brute-force-resistant algorithm). It lives only in memory while unlocked and is wiped the moment the app locks.
- **Encrypted at rest.** Entries and photos are encrypted with **AES-256-GCM**.
- **Your backups, your key.** Backups use a separate passphrase only you know.
- **No accounts, no telemetry, no ads.**

## 📸 Screenshots

| Timeline | Entry | Mood analytics | Unlock |
| :---: | :---: | :---: | :---: |
| _coming soon_ | _coming soon_ | _coming soon_ | _coming soon_ |

## 🚀 Getting Started

**Prerequisites:** [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel) and Android Studio / Xcode.

```sh
# 1. Clone
git clone https://github.com/MalicKAbdullah/reflect.git
cd reflect

# 2. Install dependencies (also fetches secure-suite-core)
flutter pub get

# 3. Run on a connected device or emulator
flutter run
```

**Build a release APK:**

```sh
flutter build apk --release
```

Run the checks the way CI does:

```sh
flutter analyze
flutter test
```

## 🧱 Built With

- **Flutter** & **Dart** — one codebase, Android & iOS
- **Riverpod** (state) · **go_router** (navigation) · **fl_chart** (analytics) · **pdf** (year book)
- [**secure-suite-core**](https://github.com/MalicKAbdullah/secure-suite-core) — shared encryption, storage & design system

## 📄 License

[MIT](LICENSE) © 2026 Abdullah Malik — part of the [Secure Suite](https://github.com/MalicKAbdullah/secure-suite-core).
