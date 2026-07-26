# Changelog

All notable changes to PenHaven are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] — Unreleased

### Fixed
- **Share sheet**: the Sanctuary share sheet's "Share card" button now
  correctly hands off to the OS share sheet before dismissing itself —
  previously the sheet closed before the share dialog could appear, so no
  app picker ever showed up.
- **Security**: PINs and recovery codes are now stored as salted SHA-256
  hashes instead of a reversible encoding.
- **App Lock**: changing your PIN no longer silently disables biometric
  unlock if you had it enabled.
- Milestone celebration banner now displays for the intended 3.5 seconds
  (was truncated to 3s by an integer-division typo).

### Changed
- Replaced `image_picker` with `wechat_assets_picker` for gallery image
  selection across the whole app (header images, inline images, story
  covers, profile photo, banner). The picker is now themed to match the
  app's accent color for a more integrated feel.
- Recovery code generation now uses a cryptographically secure random
  source instead of a timestamp-derived value.

### Added
- GitHub Actions workflow now publishes signed release APKs to GitHub
  Releases automatically on version tags.
- README, Privacy Policy, and Contributing guide for public release.
- Simple static download website (`docs/index.html`), deployable for free
  via GitHub Pages.

---

## [0.x] — Pre-release

Initial development of the core writing experience, atmosphere system,
Sanctuary community features, and app lock.