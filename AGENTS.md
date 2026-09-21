# AutoSizeText engineering

Follow `.gtm/engineering_policy.md` and the project-local
`.agents/skills/flutter-project/SKILL.md`, especially its library reference.

- This is a widget library. Preserve its public API, text metrics, constraints,
  scaling, accessibility, grouping, lifecycle and rendering semantics.
- Keep the public minimum at Dart 3.11 / Flutter 3.41.0. `.fvmrc` pins development
  to Flutter 3.47.2; it does not raise those package requirements.
- Keep `flutter_lints` 6 and self-contained package analysis. Do not introduce
  application layers, Saropa, state managers or GTM runtime dependencies.
- After dependency setup (`fvm flutter pub get --no-example`), run
  `bash tool/validate.sh` for policy and targeted package analysis. Pass relevant
  test paths for behavior changes; `--ci` runs the stable package suite.
- CI preserves exact minimum/high SDK checks. Downgrade, demo APK and archive
  work run only for affected surfaces. Documentation-only changes run policy
  checks while every existing status name remains available.
- No golden tests, comparison baselines or tests-per-type requirements. Keep
  useful rendering and behavior tests; do not add tests for wording changes.
- `maintenance/` records completed historical work, not active instructions or
  release gates. Technical changes and new documentation are English.
- Repository policy, skills and tools stay out of published archives. Do not
  publish or change package versions as part of routine engineering setup.
