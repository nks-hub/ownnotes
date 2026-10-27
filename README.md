# OwnNotes

[![Mobile](https://github.com/nks-hub/ownnotes/actions/workflows/mobile.yml/badge.svg)](https://github.com/nks-hub/ownnotes/actions/workflows/mobile.yml)
[![Version](https://img.shields.io/github/v/tag/nks-hub/ownnotes?label=version)](https://github.com/nks-hub/ownnotes/tags)
[![Platform](https://img.shields.io/badge/platform-Android%207.0%2B%20%7C%20iOS%2015%2B-blue)](#requirements)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.7-02569B)](https://flutter.dev)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

> Nextcloud Notes client for Android and iOS, written in Flutter. Notes are kept on the device too, so you can edit them offline; the server keeps plain Markdown files and categories map to folders.

[Česky](README.cs.md)

## Features

- 👥 **Accounts** - several Nextcloud accounts, sign-in through Login Flow v2, credentials in the Android Keystore or Apple Keychain
- 💾 **Offline** - local SQLite database, autosave, sync and manual conflict resolution
- ✍️ **Editor** - Markdown with an opt-in preview, checklists, templates, edit history and in-note search
- 🗂️ **Organizing** - categories, favourites, saved views and filters for attachments, tasks and sync state
- 📎 **Attachments** - transfer queue with a local cache, sharing through Nextcloud, receiving content from other apps
- 📱 **Device** - home screen widgets, app lock, light and dark theme, list and editor side by side on wide screens
- 🔄 **Background sync** - Android WorkManager; the system decides when it actually runs
- 🌍 **Languages** - Czech, English and German
- 📊 **Telemetry** - optional Sentry and Rybbit, compiled in only when configured at build time and switchable off in Settings

Open items (full backup export, server trash and history, background sync on iOS, `notify_push`, desktop builds) are tracked in [TODO.md](TODO.md).

## Requirements

- Nextcloud server with the [Notes app](https://apps.nextcloud.com/apps/notes)
- Android 7.0 (API 24) or newer, iOS 15.0 or newer
- Flutter 3.47.7 and Dart 3.13.5 for building (pinned in `.flutter-version`)

## Installation

- Android: closed testing on Google Play, opt in at https://play.google.com/apps/testing/com.nkshub.nextcloudnotes
- iOS: TestFlight

Build from source:

```bash
git clone https://github.com/nks-hub/ownnotes.git
cd ownnotes/apps/mobile
flutter pub get
flutter run
```

## Configuration

Release builds read `apps/mobile/android/key.properties` (gitignored) with the upload keystore; there is no fallback to the debug key. `--android-project-arg=candidate=true` builds `com.nkshub.nextcloudnotes.candidate` ("OwnNotes Candidate"), which installs next to the store app.

Crash reporting and analytics stay off unless the build gets a configuration, see [`apps/mobile/telemetry.env.example`](apps/mobile/telemetry.env.example). The iOS signing team is passed on the `xcodebuild` command line as `DEVELOPMENT_TEAM`.

## Documentation

- [Implementation plan](docs/architecture/implementation-plan.md)
- [Synchronization invariants](docs/architecture/synchronization.md)
- [Development workflow](docs/architecture/development.md)
- [Candidate behavior and limitations](docs/architecture/candidate.md)
- [Evidence and remaining gates](docs/acceptance/status.md)
- [Protocol sources](contracts/notes/README.md)

## Development

```bash
git config core.hooksPath .githooks
bash tool/check.sh
bash tool/check_mobile.sh
```

`check_mobile.sh` serializes Flutter tests with `flock` where it is installed; on Windows run one checkout at a time.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-change`)
3. Commit your changes (`git commit -m 'feat: add my change'`)
4. Push the branch (`git push origin feature/my-change`)
5. Open a Pull Request

## Support

- 📧 **Email:** dev@nks-hub.cz
- 🐛 **Bug reports:** [GitHub Issues](https://github.com/nks-hub/ownnotes/issues)

## License

MIT License — see [LICENSE](LICENSE) for details.

---

<p align="center">Made with ❤️ by <a href="https://github.com/nks-hub">NKS Hub</a></p>
