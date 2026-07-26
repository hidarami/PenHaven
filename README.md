<div align="center">

# 🌙 PenHaven

**A quiet sanctuary for your words.**

*No streaks. No guilt. No judgment. Just you, and the time of day.*

[![Flutter](https://img.shields.io/badge/Flutter-3.19%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-informational)]()
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Made with Supabase](https://img.shields.io/badge/backend-Supabase-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)

[Download](#download) · [Features](#features) · [Philosophy](#philosophy) · [Getting Started](#getting-started) · [Contributing](#contributing)

</div>

---

## About

PenHaven (codename **Flow**) is a private writing and journaling app for people
who want to write for themselves first, and share selectively second. It's not
a social network, not a productivity tool, not a notes app — it's a writing
sanctuary.

Every entry is complete the moment you write it. There are no drafts, no
"publish-ready" states, no pressure. The app's atmosphere shifts with the time
of day and the weather outside your window, so writing at 3PM on a golden
afternoon *feels* different from writing at midnight in the rain.

## Philosophy

> Flow was built to fix two things every other writing app gets wrong: it
> makes everything feel like a task, and it makes privacy feel like
> incompleteness. Your writing is not a product to be shipped. It is not a
> commitment you are behind on. It is something that happens when you sit
> down to write — and stops when you stop — and is complete in either case.

**The Mercy Rule** — nothing in PenHaven turns red or nags you. Old to-dos and
unfinished threads quietly fade away instead of shaming you for leaving them.
The app trusts you to know your own life.

Read the full [vision](vision.md) and [product philosophy](product.md).

## Features

### ✍️ Writing
- Distraction-free, block-based WYSIWYG editor (headings, quotes, checklists,
  code blocks, image grids, embeds)
- Inline formatting — bold, italic, underline, strikethrough, highlights, links
- Automatic version history with restore
- Custom reading fonts (15+ serif & sans options)
- Export to PDF, TXT, or a beautifully designed social card

### 🌗 Atmosphere
- The background, lighting, and overlays shift with real time-of-day and
  live weather — golden 3PM light, midnight ink, rainy mornings, Sunday
  parchment glow
- 20 hand-designed manual themes if you'd rather choose your own vibe
- A gentle "Comfort Mode" that gradually warms the interface if your words
  suggest you're having a hard day

### 🕊️ The Sanctuary (optional, always off by default in spirit)
- Share entries publicly or anonymously
- Read and respond to reflections from other writers
- "Write Backs" — respond to someone else's entry with a reflection of your
  own, private or published
- Never algorithmic, never gamified — just quiet resonance

### 🔒 Privacy & Security
- Fully offline-first — your journal lives on your device by default
- Optional cloud sync only if you sign in
- App lock via PIN (salted + hashed, never stored in plaintext) and
  biometric unlock
- No ads, ever. No data sales. See [PRIVACY.md](PRIVACY.md)

### 🕰️ The Mercy Rule
- Uncompleted to-dos fade away 48h after creation (24h after their deadline)
  instead of guilt-tripping you
- "Time Capsule" letters to your future self, with "on this day" resurfacing

## Screenshots

> _Add screenshots to `docs/screenshots/` and reference them here before your
> first public release — e.g._
>
> `![Story panel](docs/screenshots/story-panel.png)`

## Tech Stack

| Layer | Choice |
|---|---|
| Framework | Flutter 3.19+ / Dart 3.3+ |
| Local storage | SQLite via `sqflite` |
| Cloud sync & community | Supabase (Postgres, Auth, Storage, Edge Functions) |
| State management | `provider` |
| Media picking | `wechat_assets_picker` (+ `image_cropper`) |
| Typography | `google_fonts` |
| Notifications | `flutter_local_notifications` |

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.19 or newer
- A configured Supabase project (optional — the app runs fully offline
  without one; see [Configuration](#configuration))

### Run locally

```bash
git clone https://github.com/hidarami/PenHaven.git
cd PenHaven
flutter pub get
flutter run
```

## Configuration

Cloud sync and the Sanctuary community features require a free
[Supabase](https://supabase.com) project:

1. Create a new Supabase project.
2. Run the schema in `DATABASE_SCHEMA.md` via the Supabase SQL editor
   (that file documents the tables — adapt as needed for your project).
3. Enable **Email** auth under **Auth → Providers**.
4. Update `lib/services/supabase_service.dart` with your project URL and
   anon key:
```dart
   static const String _supabaseUrl = 'YOUR_SUPABASE_URL';
   static const String _supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```
5. (Optional) Deploy the `supabase/functions/share` Edge Function for rich
   link previews when sharing entries.

Without Supabase configured, PenHaven works entirely offline — journaling,
atmosphere, themes, fonts, PIN lock, and export all function with zero setup.

## Project Structure

lib/
├── atmosphere/ # Time/weather-reactive painters & overlays
├── data/ # SQLite DAOs + JSON backup/restore
├── models/ # Plain data models (Entry, Story, Todo, ...)
├── providers/ # App-wide state (Provider/ChangeNotifier)
├── screens/ # All UI, organized by feature area
├── services/ # Image, lock, notification, permission, Supabase
├── theme/ # Colors & typography — single source of truth
└── widgets/ # Shared, reusable widgets

See [information_architecture.md](information_architecture.md) for the full
navigation map.

## Building for Release

### Android
```bash
flutter build apk --release
```
A GitHub Actions workflow (`.github/workflows/build-apk.yml`) builds a signed
release APK automatically and — when you push a `v*` tag — publishes it to
GitHub Releases. Required repo secrets:

- `RELEASE_KEYSTORE_BASE64` — your keystore, base64-encoded
- `RELEASE_STORE_PASSWORD`
- `RELEASE_KEY_PASSWORD`
- `RELEASE_KEY_ALIAS`

### iOS
```bash
flutter build ipa --release
```
(Requires an Apple Developer account and Xcode signing configuration.)

## Download

📥 **[Download the latest release](https://github.com/hidarami/PenHaven/releases/latest)**

Or visit the [download website](docs/index.html) (deployable free via GitHub
Pages — see below).

To host the download page for free:
1. Push this repo to GitHub.
2. Go to **Settings → Pages**.
3. Set **Source** to your `main` branch, folder `/docs`.
4. Your site will be live at `https://hidarami.github.io/PenHaven/`.

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md)
first.

## Privacy

PenHaven is built privacy-first. Read the full [Privacy Policy](PRIVACY.md).

## License

Distributed under the MIT License. See `LICENSE` for details.

## Acknowledgments

- [Flutter](https://flutter.dev) & [Supabase](https://supabase.com)
- [Google Fonts](https://fonts.google.com) — Crimson Pro, Inter, and friends
- Everyone who writes at 3AM and closes the app feeling a little lighter

---

<div align="center">

*A writing app that treats your private words as complete and valuable on
their own.*

</div>