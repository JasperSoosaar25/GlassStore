# Contributing to GlassStore

Thanks for helping out. This project stays useful by staying simple —
read this once before your first PR.

## Ground rules

1. **Keep it legal.** No scraping behind authentication, no circumvention of
   Apple signing, no bundled Apple assets, no decompiled code from anyone's
   app. Data comes from the public endpoints in `docs/RESEARCH.md` only.
2. **Zero-entitlement policy.** The app ships with no special entitlements so
   it installs identically for everyone. If your feature needs an entitlement
   (push, iCloud, App Groups…), open an issue first — the default answer is no.
3. **iOS 26.0 minimum.** Liquid Glass APIs are the point of this project.
   Don't add `#available` fallback branches; raise the discussion in an issue
   instead.

## Code style

- Swift, 4-space indentation, no force unwraps (`!`), no `try!`.
- `async/await` only — no completion-handler APIs.
- New parsing or formatting logic must land with unit tests and, where
  relevant, a fixture in `GlassStoreTests/Fixtures/`.
- After adding/removing Swift files, regenerate the project:
  `python3 scripts/gen_pbxproj.py` (or use `project.yml` with XcodeGen).

## Suggested workflow

1. Fork, branch (`feat/…` or `fix/…`).
2. `xcodebuild -project GlassStore.xcodeproj -scheme GlassStore test`
   or just Cmd+U in Xcode.
3. PR with a short description and screenshots for UI changes
   (drop them in `screenshots/`).
