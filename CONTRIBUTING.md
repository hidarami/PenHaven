# Contributing to PenHaven

Thanks for wanting to help make PenHaven better — here's how to get started.

## Ground rules

- Be kind. This is a small project built with care; treat contributors and
  users the way the app treats its writers — gently.
- Keep the philosophy in mind: no streaks, no guilt mechanics, no dark
  patterns. If a feature pressures the user, it doesn't belong here.

## Setting up

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO
flutter pub get
flutter run
```

The app runs fully offline with zero configuration. Supabase is only needed
if you're working on Sanctuary/cloud-sync features — see the
[README's Configuration section](README.md#configuration).

## Branching & commits

- Branch from `main`: `feature/short-description` or `fix/short-description`
- Keep commits focused; write commit messages in the imperative mood
  ("Fix share sheet dismissal", not "Fixed" or "Fixes")
- Run `dart format .` before committing

## Code style

- Follow the existing structure: DAOs in `lib/data/`, models in
  `lib/models/`, screen-specific widgets colocated under
  `lib/screens/<feature>/`
- Prefer `const` constructors wherever possible
- Colors and text styles belong in `lib/theme/app_colors.dart` and
  `lib/theme/app_typography.dart` — avoid hardcoding new colors inline
- Keep provider/state logic out of widgets where reasonably possible

## Pull requests

1. Make sure `flutter analyze` passes with no new warnings.
2. Describe **what** changed and **why** — screenshots/GIFs for UI changes
   are appreciated.
3. Link any related issue.
4. One logical change per PR where possible — smaller PRs get reviewed faster.

## Reporting bugs

Please include:
- Flutter/Dart version (`flutter --version`)
- Platform (Android/iOS) and OS version
- Steps to reproduce
- Expected vs. actual behavior
- Logs/screenshots if available

## Feature requests

Open an issue describing the problem you're trying to solve (not just the
feature) — we want to make sure any addition fits PenHaven's philosophy of
calm, pressure-free writing before it's built.

Thank you for contributing! 🌙