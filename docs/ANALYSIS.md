# Forensic analysis — `AppStore_Cloned.ipa`

**Date:** 2026-11-13 · **Analyst:** automated static teardown (no code from the
file was executed; nothing from it is redistributed in this repository)

This document records what the uploaded IPA actually is, why the original
request ("reconstruct the source, publish it for the community, make it work
for everyone") is not achievable for *this* file, and what this repository
does instead.

---

## 1. Identification

| Property | Value |
|---|---|
| File | `AppStore_Cloned.ipa` — 7,973,430 bytes |
| SHA-256 | `a70bf9129d27ca22e262f88895d33d99a3ee799d27d5ecee5ff0292759a6b106` |
| Container | ZIP (store method), 142 entries, one app bundle |
| Bundle | `AppStore.app` (142 files, ~16.5 MB uncompressed) |
| Bundle ID | `com.apple.AppStore.custom` (original: `com.apple.AppStore`) |
| Display name | **"App Store 2"** |
| Counterpart | `LSCounterpartIdentifiers` still points at `com.apple.AppStore` |
| Main binary | `AppStore`, 11,953,696 bytes, arm64, SHA-256 `4cee1c02d7f7bacb62dee0c241d7dd00bd5d72963d034b82fba435b237475558` |
| Minimum OS | **27.0** |
| Built with | `DTSDKName: iphoneos27.0.internal`, `DTXcode: 2700` (Xcode 27), `DTPlatformBuild: 24A417` — an **Apple-internal SDK** |

**Verdict:** the executable is **Apple's genuine, first-party App Store
application** (the store client that ships inside iOS), re-badged for
side-by-side installation. It is not a community "clone" app; the word
"cloned" in the filename refers to re-badging Apple's own binary.

Evidence chain:

1. **Private frameworks only Apple's App Store links against** —
   `AppStoreKit`, `AppStoreComponents`, `AppleMediaServices`,
   `AppleMediaServicesUIKitInternal`, `JetEngine`, `JetUI`, `AuthKit`,
   `SpringBoardServices`, `FrontBoardServices`, `GameCenterUI`,
   `FamilyCircleUI`, `TemplateKit`… (70+ linked dylibs, ~27 of them
   Apple-private).
2. **Apple-internal class inventory** — 296 Objective-C classes visible in
   the symbol table, dominated by `AMS*` (Apple Media Services):
   `AMSEngagement`, `AMSUIDynamicViewController`, `AAUISignInController`,
   `ADTransparencyViewController`, plus Swift symbols for `AppStore`,
   `StoreKit`, `ASDAppQuery`.
3. **Apple-internal build provenance** — `iphoneos27.0.internal` SDK, Xcode
   27 (`27A200c`), platform build `24A417`. Third parties cannot build
   against internal SDKs; this binary came out of Apple's build system.
4. **Zero FairPlay encryption** — the Mach-O has **no
   `LC_ENCRYPTION_INFO_64` at all** (checked across all 122 load commands).
   App Store *downloads* are always FairPlay-encrypted; the absence of the
   load command means this came from an OS image / internal build, not a
   device dump of a store download.
5. **Ad-hoc re-signature** — the code signature's CMS slot is an empty
   8-byte blob (`0xFADE0B01`, length 8): an **ad-hoc / ldid-style
   signature**. No `embedded.mobileprovision`, no `iTunesMetadata.plist`,
   no `SC_Info/` — consistent with a hand-repacked system app.

## 2. The entitlement problem (the fatal one)

The embedded entitlements blob (slot 5, `0xFADE7171`, 12,793 bytes) contains
**107 keys**, all Apple-private. Highlights:

- `com.apple.private.appstored` + `appstored.install-apps` /
  `update-apps` / `xpc.updates`
- `com.apple.private.applemediaservices`, `appstorecomponents`
- `com.apple.private.FairPlayIOKitUserClient.access`,
  `fairplay-client: 1699554724`
- `com.apple.private.security.system-application`
- `com.apple.private.MobileGestalt.AllowedProtectedKeys` =
  `["UniqueDeviceID", "SerialNumber"]`
- `com.apple.private.tcc.allow` = `["kTCCServiceCamera", "kTCCServiceAddressBook", "kTCCServiceMediaLibrary", "kTCCServiceFaceID"]`
- `com.apple.private.storekit`, `payment.all-access`,
  `game-center`, `screen-time`, `keystore.*`, `ids.*`…

`application-identifier` inside that blob still reads
**`com.apple.AppStore`** — the re-badger changed the bundle ID in
`Info.plist` but not the entitlements.

**Consequences:**

- No community signing tool (AltStore, SideStore, Sideloudly, ESign,
  Impactor-class tools) can issue a provisioning profile containing
  `com.apple.private.*`. Re-signing therefore strips or refuses them, and
  the app dies at its first privileged XPC call (appstored / AMS /
  FairPlay) — or refuses to install outright.
- The **only** mechanism that grants arbitrary entitlements is the CoreTrust
  bug, i.e. TrollStore — which supports **14.0b2 – 16.6.1, 16.7 RC and
  17.0 only**. It does not exist on iOS 26/27 (the bug was patched in
  17.0.1 and remains patched). See `docs/RESEARCH.md`.
- And the binary won't even *install* below iOS 27.0, because
  `MinimumOSVersion` is 27.0 — which already violates the requested
  "minimum iOS 26" requirement.

The set of devices where this file works as shipped is effectively empty.

## 3. Why no "source reconstruction"

- What decompilers produce from a 12 MB arm64 Swift/ObjC binary is
  pseudo-code approximations, not source — and it would still be Apple's
  copyrighted code. Publishing it (or the binary, or its assets:
  `Assets.car`, `.caar`, `.loctable`, `LaunchScreen.storyboardc`, the widget
  extension `AppStoreWidgetsExtension`) is infringement, and GitHub honors
  DMCA takedowns.
- This repository therefore contains **zero bytes** derived from the IPA.
  The app icon, all code, all docs are original. Fixtures in the test suite
  are captures of *public API responses* (`itunes.apple.com`), which is
  normal engineering practice and unrelated to the IPA.

## 4. Diagnosis summary ("bugs")

| # | Finding | Severity | Fixable by community? |
|---|---|---|---|
| 1 | Ad-hoc signature (empty CMS) | Fatal on stock iOS | No — only Apple's identity (or CoreTrust, which is gone) |
| 2 | 107 Apple-private entitlements | Fatal after any re-sign | No |
| 3 | `MinimumOSVersion` 27.0 | Blocks iOS 26 devices | Contradicts the stated requirement; cannot be "fixed" without re-badging deeper |
| 4 | Entitlements still claim `com.apple.AppStore` | Identity mismatch | No |
| 5 | Widget extension equally ad-hoc | Same as #1 | No |
| 6 | No provisioning profile | Expected for system-app repacks | Moot given #1–#4 |

Structural integrity is otherwise fine: the ZIP is valid, the Mach-O parses
cleanly, all five segments are present, and the code-directory hashes cover
the binary consistently. Nothing is corrupted — it is simply not a
distributable app, and never can be.

## 5. What this repository does instead

The stated end goal was: *"a same-looking app with the same design language,
Liquid Glass, that the community can fork and extend — minimum iOS 26,
working the same for everybody."* That is delivered here as **GlassStore**:
original code, public data, zero entitlements, honest docs. See the README.
