# AutoSizeText

`AutoSizeText` is a Flutter widget that chooses the largest allowed font size
that fits its layout constraints. It supports plain and rich text, synchronized
groups, nonlinear `TextScaler`s, intrinsic sizing, and inline `WidgetSpan`s.

Version 4 requires Dart 3.11 or later (before Dart 4) and Flutter 3.41 or later.

## Install

```yaml
dependencies:
  auto_size_text: ^4.0.0
```

```dart
import 'package:auto_size_text/auto_size_text.dart';
```

## Basic usage

Give the widget meaningful constraints on the dimensions it should fit:

```dart
SizedBox(
  width: 220,
  height: 80,
  child: AutoSizeText(
    'This text shrinks until it fits on two lines.',
    style: TextStyle(fontSize: 36),
    maxLines: 2,
  ),
)
```

The search starts at the effective style size, clamped by `maxFontSize`, and
stops at `minFontSize`. The defaults are 12 for `minFontSize`, no additional
maximum, and 1 for `stepGranularity`.

```dart
AutoSizeText(
  'Choose from an explicit size domain.',
  presetFontSizes: [40, 28, 20, 14],
  maxLines: 2,
)
```

`presetFontSizes` must be non-empty, finite, non-negative, and non-increasing
(largest to smallest). Adjacent duplicates are accepted. When supplied, it
replaces `minFontSize`, `maxFontSize`, and `stepGranularity`.

If the text still does not fit at its smallest candidate, use
`overflowReplacement` to show another widget:

```dart
AutoSizeText(
  'Text that must remain readable.',
  minFontSize: 18,
  maxLines: 1,
  overflowReplacement: Text('Not enough room'),
)
```

Choose either `overflow` or `overflowReplacement`, not both.

## Rich text and inline widgets

`AutoSizeText.rich` preserves the source span tree, including recognizers and
semantics. `WidgetSpan` children are measured automatically during normal
layout; no placeholder dimensions are required.

```dart
AutoSizeText.rich(
  TextSpan(
    children: [
      TextSpan(text: 'Inline '),
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(Icons.star, size: 24),
      ),
      TextSpan(text: ' widgets resize with their run.'),
    ],
  ),
  style: TextStyle(fontSize: 32),
  maxLines: 2,
)
```

For rich text, the effective root style size is the auto-size reference.
Explicit descendant sizes keep their proportions through the selected
`TextScaler`. If the root reference is zero, the selected candidate supplies
the root size while explicitly sized descendants keep their logical sizes.

## Text scaling

When `textScaler` is omitted, `AutoSizeText` uses the ambient
`MediaQuery.textScalerOf(context)`, including nonlinear accessibility scaling.
An explicit scaler takes priority:

```dart
AutoSizeText(
  'Scaled accessibly',
  textScaler: TextScaler.linear(1.2),
  maxLines: 1,
)
```

Custom scalers must return finite, non-negative values and be monotone
non-decreasing for the font-size search to be well-defined. The legacy
`textScaleFactor` parameter remains as a deprecated linear compatibility
bridge. Do not provide it together with `textScaler`.

## Groups

Use one stable `AutoSizeGroup` to coordinate several widgets, or let
`AutoSizeGroupBuilder` own it:

```dart
AutoSizeGroupBuilder(
  builder: (context, group) => Row(
    children: [
      Expanded(child: AutoSizeText('Short', group: group)),
      Expanded(
        child: AutoSizeText(
          'A much longer label',
          group: group,
          maxLines: 1,
        ),
      ),
    ],
  ),
)
```

Each member stays within its own candidate domain. Members share the smallest
effective size they can represent; different minima, presets, or scalers can
therefore make a member stop at its own smallest candidate instead of matching
exactly. Do not create a new `AutoSizeGroup` during every build.

## Main options

| Option | Behavior |
|---|---|
| `style`, `strutStyle` | Define the text and vertical layout metrics. |
| `minFontSize`, `maxFontSize` | Bound the regular candidate domain. |
| `stepGranularity` | Sets the step from `minFontSize`; must be at least 0.1. |
| `presetFontSizes` | Uses only the supplied non-increasing sizes. |
| `maxLines` | Limits lines while choosing a size. |
| `group` | Synchronizes effective sizes across members where domains allow. |
| `textScaler` | Applies explicit or ambient accessibility scaling. |
| `wrapWords` | When false, each whitespace-delimited segment must fit without an internal break; NBSP and NNBSP remain binding. |
| `overflow` | Controls painting when the smallest candidate still overflows. |
| `overflowReplacement` | Lazily displays another widget when no candidate fits. |
| `textKey` | Resolves to the element whose render object is the painted paragraph. |

Alignment, direction, locale, soft wrapping, semantics, inherited
`TextWidthBasis`, inherited `TextHeightBehavior`, and current `MediaQuery` text
metric overrides participate in both measurement and rendering.

## Layout limits

- Intrinsic width/height, dry layout, and dry baseline are supported for plain
  and rich text.
- An `overflowReplacement` stays lazy. Dry and intrinsic queries report the
  constrained paragraph at the smallest candidate, not the replacement's
  geometry, so dry and normal layout can intentionally differ in overflow.
- A `WidgetSpan` child is queried only during normal (wet) layout. Its dry size,
  dry baseline, and four intrinsic contributions are treated as zero. This
  keeps arbitrary wet-only children safe but can select a different dry
  candidate and geometry.
- Candidate search assumes monotone text and inline-child sizing. A
  non-monotone inline child still terminates deterministically, but no global
  optimum is promised.

## Migrating from 3.x

- Update to Dart 3.11+ and Flutter 3.41+ before selecting 4.x. Applications
  that must stay on older SDKs should remain on their existing 3.x dependency.
- Replace `textScaleFactor: value` with
  `textScaler: TextScaler.linear(value)`. The old parameter is deprecated but
  still available; providing both parameters throws `ArgumentError` in release
  mode.
- `textKey` still locates the painted paragraph, but its widget is an
  implementation detail and is no longer guaranteed to be a `Text`. Avoid
  casting the keyed widget in tests.
- Invalid or non-finite sizing inputs now throw `ArgumentError` in release
  mode. Fractional minima are supported, and regular steps are anchored at
  `minFontSize`.
- Measurement now follows ambient nonlinear scaling, bold text, spacing and
  line-height overrides, direction, locale, strut, and inherited paragraph
  behavior. Corrected layouts can therefore choose a different size than 3.x.
- Rich text, heterogeneous groups, intrinsic parents, and automatic
  `WidgetSpan` layout use the contracts described above, including the lean
  dry-layout limits.

See the runnable [example](example/main.dart), the [changelog](CHANGELOG.md),
and the [MIT license](LICENSE).
