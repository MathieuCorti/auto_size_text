# Risk-based verification

Choose tests for observable behavior and meaningful contracts, not file counts.

- Cosmetic changes: analysis and visual inspection when useful; no automatic new tests.
- Business logic and regressions: focused unit/behavior tests.
- Important UI interactions: widget tests for input, navigation, state changes, layout constraints, and accessibility.
- Integrations and SDKs: serialization, method-channel, authorization, privacy, error/retry, and compatibility tests where relevant.

Preserve existing useful behavioral coverage, especially auth, purchases, account deletion, privacy, game rules, multiplayer authorization, and hidden information. Stable affected-surface suites run before integration; release checks remain separate. There is no default global coverage percentage or requirement to test every class/view/state.

Never add golden tests or stored screenshot/image comparison baselines, including under another name. Prefer meaningful behavioral/layout assertions and baseline-free manual or agent visual inspection. Do not create tests for empty generated feature scaffolds.

Use `bash tool/validate.sh` for the normal blocking policy/boundary/analysis path, supplying relevant test paths. Use `--ci` for stable package suites. Project `AGENTS.md` may describe additional server, emulator, or native lanes. Keep optional suggestions separate, and report commands and unresolved failures honestly.
