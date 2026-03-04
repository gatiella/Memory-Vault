# 🔐 Memory Vault

A clean, secure notes and to-do app built with Flutter & Firebase — works offline, syncs to Google Drive.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter) ![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?logo=firebase) ![License](https://img.shields.io/badge/license-MIT-green)

---

## Features

- 📝 **Rich notes** — full formatting via Quill editor (bold, lists, code blocks, links)
- ✅ **To-do lists** — with reminders and completion tracking
- ☁️ **Google Drive backup** — notes and todos saved to your own `MyNotes/` folder
- 📶 **Offline first** — create and edit without internet, auto-syncs when back online
- 🎨 **Color-coded notes** — 12 accent colors, tinted cards, grid & list views
- 🔍 **Search** — instant filter across titles and content
- 📌 **Pin notes** — keep important notes at the top
- 🌙 **Dark & light theme**
- 🔒 **Biometric lock** — fingerprint/face ID on app open

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter |
| Auth | Firebase Auth + Google Sign-In |
| Database | Cloud Firestore (offline persistence) |
| Backup | Google Drive API (`drive.file` scope) |
| Editor | flutter_quill |
| Notifications | flutter_local_notifications |

---

## Getting Started

```bash
git clone https://github.com/your-username/memory-vault.git
cd memory-vault
flutter pub get
```

Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) from Firebase Console, then:

```bash
flutter run
```

> **Note:** Enable the [Google Drive API](https://console.cloud.google.com/apis/library/drive.googleapis.com) in your Google Cloud project and add `https://www.googleapis.com/auth/drive.file` to your OAuth consent screen scopes.

---

## Download
[![Download APK](https://img.shields.io/badge/Download-APK-green?logo=android)](https://github.com/your-username/memory-vault/releases/latest/download/app-release.apk)

## License

MIT © 2026 Memory Vault
