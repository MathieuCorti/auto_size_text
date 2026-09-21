#!/usr/bin/env bash
# One blocking local path. No automatic tests for a cosmetic change.
set -euo pipefail
validation_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$validation_root"
python3 tool/quality_check.py check
if [[ "${1:-}" == "--policy" ]]; then exit 0; fi
validation_ci=false
if [[ "${1:-}" == "--ci" ]]; then validation_ci=true; shift; fi
while IFS= read -r package_root; do
  (
    cd "$validation_root/$package_root"
    dart_command=(dart)
    flutter_command=(flutter)
    if [[ -f .fvmrc || -f "$validation_root/.fvmrc" ]]; then
      dart_command=(fvm dart)
      flutter_command=(fvm flutter)
    fi
    # The separately pinned demo has its own CI lane and dependency resolution.
    "${flutter_command[@]}" analyze --no-pub --fatal-infos --fatal-warnings \
      lib test example/main.dart
    if [[ "$validation_ci" == true || "$#" -gt 0 ]]; then
      if [[ -d test || "$#" -gt 0 ]]; then
        if grep -q 'sdk: flutter' pubspec.yaml; then
          "${flutter_command[@]}" test "$@"
        else
          "${dart_command[@]}" test "$@"
        fi
      fi
    fi
  )
done < <(python3 tool/quality_check.py package-roots)
