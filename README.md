<div align="center">

# GlassStore

**An open-source, App Store–styled storefront client for iOS 26.**

Liquid Glass design language · public storefront feeds · no keys · no tracking · no special entitlements

</div>

---

## What is this?

GlassStore looks and feels like the iOS 26 App Store — tab bar, Today page,
charts, search, product pages — but it is a **100% original codebase** built
with public SwiftUI APIs and fed by **public, key-less Apple endpoints**
(legacy iTunes chart RSS + iTunes Search/Lookup). It is written for the
sideloading community: fork it, reskin it, teach with it, ship it.

- **Design:** iOS 26 Liquid Glass throughout — floating glass tab bar
  (`tabBarMinimizeBehavior`), interactive glass GET pills
  (`buttonStyle(.glassProminent)`), zoom navigation transition into detail
  pages, glass search field.
- **Data:** `itunes.apple.com` public chart feeds (Top Free / Top Paid / Top
  Grossing / New) and the public Search/Lookup API. Nothing else. No account,
  no key, no telemetry from this app.
- **Behavior:** it never installs or signs anything itself — every GET button
  opens the app's official page on the real App Store. It is a discovery and
  browsing client, nothing more.
- **Installability:** zero entitlements, so it behaves **identically** whether
  you install it with Xcode, AltStore, SideStore, Sideloadly or anything else
  that can sign a normal app.

> GlassStore is an independent community project. It is not affiliated with,
> endorsed by, or connected to Apple. "App Store" and related marks belong to
> Apple. All feed content and artwork belong to their respective publishers.

## Screenshots

Design previews (rendered from the spec, not device captures) live in
[`screenshots/`](screenshots/).

## Requirements

| | |
|---|---|
| Device | iPhone 11 or newer (anything that runs iOS 26) |
| OS | **iOS 26.0 or later** (Liquid Glass ships with iOS 26 — that's the floor by design) |
| Building | Xcode 26 or newer, with the iOS 26 SDK |
| Tests | Same as above; run on any iOS 26 simulator |

## Quick start (60 seconds)

```bash
git clone https://github.com/glassstore-community/GlassStore
cd GlassStore
open GlassStore.xcodeproj
```

Pick your team in *Signing & Capabilities* (or let Xcode manage it), choose a
simulator, press Cmd+R. That's it — no keys, no setup.

Prefer XcodeGen? `brew install xcodegen && xcodegen generate` rebuilds the
project from `project.yml`.

## Installing on a device

See **[INSTALL.md](INSTALL.md)** — step-by-step for Xcode, AltStore,
SideStore, Sideloadly and friends, plus the honest compatibility matrix
(including the TrollStore reality).

## Project layout

```
GlassStore/
├── GlassStore/            # app target
│   ├── Support/           # app entry, root tabs
│   ├── Models/            # StoreItem + Codable shapes for both feeds
│   ├── Services/          # storefront service, image cache, region store
│   ├── Views/             # Today / Charts / Search / Detail / About
│   ├── Components/        # glass pills, stars, state views, icons
│   └── Assets.xcassets    # app icon + accent color
├── GlassStoreTests/       # 24 unit tests + live-captured fixtures
├── GlassStore.xcodeproj   # generated (see below)
├── project.yml            # XcodeGen spec
├── docs/                  # forensic + research write-ups
└── screenshots/           # design previews
```

The `.xcodeproj` is **generated** by `scripts/gen_pbxproj.py` (kept in the
repo, deterministic UUIDs) so diffs stay clean. Don't hand-edit it; add
files, rerun the generator (or use XcodeGen). `scripts/gen_icon.py` regenerates
the app icon from scratch.

## Why is the minimum iOS 26.0?

Because Liquid Glass is the entire point. `glassEffect`, `.glassProminent`,
`tabBarMinimizeBehavior` and friends are iOS 26 APIs; forcing the floor to
26.0 means every device that can run GlassStore gets the full design, no
fallback branches, no degraded mode. Older devices (and therefore TrollStore
on ≤ iOS 17) simply can't run iOS 26 — see INSTALL.md for the full picture.

## Forking it (the fun part)

1. Rename: bundle ID (`com.glassstore.app` → yours) in both
   `project.pbxproj`/`project.yml`, plus the display name in `Info.plist`.
2. Retint: accent color in `Assets.xcassets` — every glass pill follows it.
3. Rework the tabs in `Support/RootView.swift`; each tab is self-contained.
4. Swap the data layer by implementing `StorefrontFetching` — one protocol,
   three methods.

## License

MIT — see [LICENSE](LICENSE). Fixtures in `GlassStoreTests/Fixtures/` are
captures of public API responses, kept tiny for testing only.
