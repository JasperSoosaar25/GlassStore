# Installing GlassStore on a device

GlassStore is a normal app with **zero special entitlements**. That is a
deliberate design decision: it means every signing path behaves identically.
This guide covers every common method, then the honest compatibility matrix.

> **Rule of thumb:** if a tool can install a plain SwiftUI app, it can install
> GlassStore. If a method isn't listed here, it still works — the app asks
> for nothing special.

---

## 1. Xcode (free Apple ID is enough)

1. `open GlassStore.xcodeproj`
2. Select the **GlassStore** target → *Signing & Capabilities*.
3. Tick *Automatically manage signing*, pick your *Team*
   (a free "Personal Team" works).
4. Connect the device, select it, **Cmd+R**.

Free-account caveats (Apple's rules, not the app's):

- Profile lasts **7 days** — re-run from Xcode (or refresh) weekly.
- Free accounts keep **3 apps** signed at a time.
- First run: Settings → General → VPN & Device Management → trust your
  developer profile.

## 2. AltStore / AltCloud

1. Build the app archive in Xcode (`Product → Archive`), then
   *Distribute App → Development*, or build with
   `xcodebuild -scheme GlassStore -configuration Release archive`.
2. In AltStore, *Install* the `.ipa` (or sideload via AltServer).
3. Or skip the Mac: in Xcode, `Product → Destination → Any iOS Device`,
   build, and use the `.app` from the build products.

The app needs no capabilities, so AltStore never has to strip anything.

## 3. SideStore (on-device signing)

Same as AltStore: point SideStore at the `.ipa` (or build products), sign
with your Apple ID, install. Refresh cadence follows your account type.

## 4. Sideloadly / ESign / i4Tools and friends

Drag `GlassStore.ipa` (built via Xcode archive, or the unsigned
`GlassStore-unsigned-ipa` artifact from GitHub Actions — no Mac needed)
into the tool, enter your Apple ID, install. Because there are no
entitlements, "keep entitlements" settings are irrelevant — the result is
the same for everyone.

## 5. Paid developer account ($99/yr)

Same steps as any method, but profiles last a year and support TestFlight.
GlassStore runs perfectly under TestFlight — `ITSAppUsesNonExemptEncryption`
is already declared `false` (it ships no cryptography of its own).

---

## Compatibility matrix (the honest version)

| Method | Works with GlassStore? | Notes |
|---|---|---|
| Xcode + free Apple ID | Yes | 7-day profile, 3-app limit |
| Xcode + paid account | Yes | 1-year profile, TestFlight OK |
| AltStore / AltCloud | Yes | no capabilities to strip |
| SideStore | Yes | as above |
| Sideloadly / ESign / i4Tools | Yes | same |
| **TrollStore** | **Not applicable** | TrollStore exploits a CoreTrust bug that Apple patched in iOS 17.0.1; supported versions end at iOS 17.0. Every device that can *run* iOS 26 (GlassStore's floor) is above that, and TrollStore does not exist on iOS 26/27. If the community ever wants a ≤iOS 17 build, the path is a separate branch with a frosted-glass fallback UI — track it in issues. |
| Jailbreak (checkra1n-class) | Yes, but pointless | The app doesn't need it — it's a normal app. |

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| "This app cannot be installed" | device below iOS 26.0 | Check Settings → General → About; GlassStore refuses anything under 26.0 by design |
| Profile expired after a week | free Apple ID | re-sign with your tool of choice |
| Bundle ID collision on device | you already have something at `com.glassstore.app` | change `PRODUCT_BUNDLE_IDENTIFIER` (see README → Forking) |
| Charts empty for a region | that storefront's feed is thin for that chart | pick a bigger region in About, or wait — the feeds refresh daily |
| Search 403s | rate limit (~20 req/min per client) | it's Apple's public limit; the app already debounces at 400 ms |
