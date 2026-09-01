## 4.0.0

### Breaking changes

- Raised the supported SDK floor to Dart 3.11 and Flutter 3.41.
- `textKey` now resolves to the element whose render object is the painted
  paragraph; its widget is no longer guaranteed to be a `Text`.

### Compatibility

- Added `TextScaler` support to both constructors, preserving ambient and
  explicit nonlinear accessibility scaling.
- Kept `textScaleFactor` as a deprecated linear bridge. Supplying it together
  with `textScaler` now throws `ArgumentError` in release mode.
- Preserved the plain/rich constructors, `AutoSizeGroup`,
  `AutoSizeGroupBuilder`, presets, and overflow replacement APIs.
- Aligned measurement with rendering for bold text, metric overrides, strut,
  direction, locale, wrapping, and inherited paragraph behavior.

### Fixes

- Reworked regular and preset candidate domains to support fractional minima,
  validate invalid inputs at runtime, and keep logarithmic search.
- Preserved rich span metadata and non-breaking spaces while measuring
  `wrapWords: false` content.
- Projected heterogeneous groups within each member's own candidate domain and
  hardened group transfer, removal, notification, and disposal behavior.
- Added intrinsic sizing, dry layout, and dry baseline support without
  speculative group mutation. Lazy overflow replacements use the minimum-text
  geometry for dry and intrinsic queries.
- Added automatic wet layout for `WidgetSpan` children, including run scaling,
  baselines, painting, hit testing, semantics, selection, and lifecycle. Inline
  children intentionally contribute zero geometry to dry and intrinsic paths.
- Disposed temporary text painters on success, early return, and failure paths.

### Tooling and examples

- Declared and validated the Dart 3.11 / Flutter 3.41 package floor and the
  Flutter 3.47.2 upper test pin with current lints and downgrade coverage.
- Modernized the Android demo while preserving its six scenarios and added
  smoke coverage for navigation, rich text, groups, and disposal.
- Added a deterministic Pub archive policy that keeps the package tests and
  canonical example while excluding repository-only and local files.

These changes address defect families reported upstream around text painter
lifecycle, fractional candidate domains, non-breaking spaces, modern text
scaling and metrics, intrinsic layout, inline widgets, and the demo scaffold.
This changelog does not claim or perform closure of upstream issues.

## 3.0.0
- Upgraded to null safety

## 2.1.0
- Added `textKey` parameter

## 2.0.2+1
- Fixed screenshots

## 2.0.2
- Fixed bug where `textScaleFactor` was not taken into account (thanks @Kavantix)

## 2.0.1
- Allow fractional font sizes again
- Fixed bug with `wrapWords` not working

## 2.0.0+2
- Added logo

## 2.0.0
- Significant performance improvements
- Prevent word wrapping using `wordWrap: false`
- Replacement widget in case of text overflow: `overflowReplacement`
- Added `strutStyle` parameter from `Text`
- Fixed problem in case the `AutoSizeTextGroup` changes
- Improved documentation
- Added many more tests

## 1.1.2
- Fixed bug where system font scale was applied twice (thanks @jeffersonatsafe)

## 1.1.1
- Fixed bug where setting the style of a `TextSpan` to null in `AutoSizeText.rich` didn't work (thanks @Koridev)
- Allow `minFontSize = 0`

## 1.1.0
- Added `group` parameter and `AutoSizeGroup` to synchronize multiple `AutoSizeText`s
- Fixed bug where `minFontSize` was not used correctly
- Improved documentation

## 1.0.0
- Library is used in multiple projects in production and is considered stable now.
- Added more tests

## 0.3.0
- Added textScaleFactor property with fallback to `MediaQuery.textScaleFactorOf()` (thanks @jeroentrappers)

## 0.2.2
- Fixed tests
- Improved documentation

## 0.2.1
- Fixed problem with `minFontSize` and `maxFontSize` (thanks @apaatsio)

## 0.2.0
- Added support for Rich Text using `AutoSizeText.rich()` with one or multiple `TextSpan`s.
- Improved text size calculation (using `textScaleFactor`)

## 0.1.0
- Fixed documentation (thanks @g-balas)
- Added tests

## 0.0.2
- Fixed documentation
- Added example

## 0.0.1
- First Release
