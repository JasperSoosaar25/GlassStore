# Changelog

All notable changes to GlassStore are documented here. The format follows
Keep a Changelog; versions follow SemVer.

## [1.0.0] - 2026-11-13

### Added
- Today tab: editorial hero (zoom transition into detail), trending rails,
  new-releases rail, top-grossing mini chart.
- Charts tab: Top Free / Top Paid / Top Grossing / New, numbered rows,
  region-aware, pull-to-refresh.
- Search tab: debounced live search with the system Liquid Glass search field.
- Detail pages: lookup-enriched metadata, screenshot rail, ratings, expanding
  description, What's New, information table, glass action bar.
- About tab: storefront region picker (20 storefronts), project links,
  licensing and the honesty block.
- Two-tier image cache (memory + disk) with graceful placeholder fallbacks.
- Unit test suite (24 tests) covering feed decoding, mapping, URL building
  and formatting, with fixtures captured from the live endpoints.
- Xcode project (hand-generated, deterministic) + XcodeGen spec + shared
  scheme + GitHub Actions CI.
- Full sideload guide (INSTALL.md) for Xcode, AltStore, SideStore,
  Sideloadly and friends.
