# Release Checklist

Run through this before publishing a new version of PenHaven.

## Code
- [ ] `flutter analyze` — zero errors/warnings
- [ ] `flutter test` — all tests pass (if present)
- [ ] Bump `version:` in `pubspec.yaml` (format `x.y.z+buildNumber`)
- [ ] Update `CHANGELOG.md` with the new version's notes

## Functionality smoke test
- [ ] Create a story, write an entry, add a header + inline image (verify
      the new gallery picker works end-to-end)
- [ ] Export an entry as PDF and TXT
- [ ] Set a PIN, lock the app, unlock with PIN, unlock with biometrics
- [ ] Change the PIN — confirm biometric unlock preference is preserved
- [ ] Forgot-PIN recovery flow works with the recovery code shown at setup
- [ ] Publish an entry to Sanctuary (anonymous + named), confirm it appears
      in the feed
- [ ] From a published entry, tap **Share** → **Share card** → confirm the
      native OS share sheet appears with app options (Messages, WhatsApp,
      Instagram, etc.)
- [ ] Toggle Sanctuary off/on in Settings, confirm published entries
      hide/reappear
- [ ] Confirm mercy-rule archiving on an old to-do

## Store readiness (Android)
- [ ] Signed release keystore configured via GitHub secrets
- [ ] App icon set via `flutter_launcher_icons` (`flutter pub run
      flutter_launcher_icons`)
- [ ] Privacy Policy URL ready for Play Console (host `PRIVACY.md`, e.g. via
      the GitHub Pages site)
- [ ] Screenshots captured for store listing

## Release
- [ ] Tag the release: `git tag vX.Y.Z && git push origin vX.Y.Z`
- [ ] Confirm GitHub Actions built and attached the APK to the new Release
- [ ] Update the download website (`docs/index.html`) version label if shown
- [ ] Announce 🎉