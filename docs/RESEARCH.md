# Research notes (2026-11-13)

Everything GlassStore relies on, with sources. Re-verify before relying on
any of this for your own fork.

## 1. Data endpoints (all public, no key)

Verified live from this workspace on 2026-11-13:

| Endpoint | Shape | Status |
|---|---|---|
| `https://itunes.apple.com/{storefront}/rss/topfreeapplications/limit/{n}/json` | Atom-style JSON, `feed.entry[]` | **200, verified** |
| `.../rss/toppaidapplications/...`, `.../rss/topgrossingapplications/...`, `.../rss/newapplications/...` | same | **200, verified** |
| `https://itunes.apple.com/search?term=…&entity=software&country=…&limit=…` | `results[]` | **200, verified** |
| `https://itunes.apple.com/lookup?id={trackId}&country=…` | single `results[0]` | **200, verified** |

Quirks baked into the models (all covered by tests):

- Chart entries wrap values in `{"label": …}` envelopes (`im:name`,
  `im:image`, `im:price`, …).
- With `limit=1`, some storefronts emit `entry` as a single **object**, not
  an array → `FlexibleEntries` decodes both.
- Chart icons top out at 100×100 in the feed; the image CDN accepts any
  square size, so `…/100x100bb.png` → `…/512x512bb.png`
  (`StorefrontService.upscaledIconURL`).
- Search rate limit is ~20 requests/minute per client (documented by Apple);
  the app debounces at 400 ms and never prefetches.
- Apple's newer "Marketing Tools" RSS builder (`rss.marketingtools.apple.com`)
  was flaky/502 during testing; the legacy `itunes.apple.com` feeds above are
  what shipping versions use. Swap sources by implementing
  `StorefrontFetching` — that's the whole point of the protocol.

## 2. Liquid Glass APIs (iOS 26.0+)

Used in this project, per the public SwiftUI documentation and the
community reference (conorluddy/LiquidGlassReference, retrieved 2026-11-13):

| API | Where used |
|---|---|
| `.glassEffect(_:in:)`, `Glass.regular/.clear`, `.tint(_:)`, `.interactive()` | hero art fallback, action bars |
| `GlassEffectContainer(spacing:)` | detail action bar |
| `.buttonStyle(.glassProminent)` / `.buttonStyle(.glass)` | GET pills / secondary buttons |
| `.tabBarMinimizeBehavior(.onScrollDown)` | root tab bar |
| `.searchToolbarBehavior(.minimized)` | search field |
| `.matchedTransitionSource(id:in:)` + `.navigationTransition(.zoom(sourceID:in:))` (iOS 18 APIs, fine on 26) | Today hero → detail zoom |

Availability floor: iOS 26.0 — matches the deployment target exactly, so no
`#available` branches anywhere.

## 3. Device & tooling landscape (as of 2026-11)

- **iOS 26 supported devices:** iPhone 11 and newer (A13+), i.e. the same
  set as iOS 26's Liquid Glass marketing. Sources: Apple's iOS 26 feature
  PDF (Sept 2025) and coverage by beebom/techindeep/croma, cross-checked.
- **TrollStore:** supported versions `14.0b2 – 16.6.1`, `16.7 RC`, `17.0`;
  the CoreTrust bug is patched from 17.0.1 onward and remains patched
  through iOS 26 (opa334's repo README; iCareFone's Nov 2026 status piece).
  → TrollStore is **not available on iOS 26/27**, which is why GlassStore's
  matrix in INSTALL.md lists it as not applicable rather than broken.
- **Free Apple ID signing:** 7-day profiles, 3 simultaneous apps — Apple's
  limit, applies to every tool that signs with a free account.
- **iTunes Search API limits:** ~20 calls/min, no key, documented at
  Apple's performance-partners page and the archived developer docs.

## 4. Sources consulted

- https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
- https://github.com/conorluddy/LiquidGlassReference (retrieved 2026-11-13)
- https://github.com/opa334/TrollStore (README: supported versions)
- https://performance-partners.apple.com/search-api (rate limits)
- https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/LookupExamples.html
- https://www.apple.com/os/pdf/All_New_Features_iOS_26_Sept_2025.pdf
- Live captures: `fixture_*.json` in `GlassStoreTests/Fixtures/`
  (trimmed, test-only).
