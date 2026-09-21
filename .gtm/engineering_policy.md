# Lean Flutter engineering foundation

Bundle version: 0.4.0. This repository owns this copy. CLI upgrades never overwrite it.

## Authority and scope

Read the root `AGENTS.md`, this policy, and the relevant local skill reference before changing a surface. Specific project instructions refine this foundation. Historical plans describe history, not additional requirements. Keep instructions, diagnostics, comments, test names, and engineering documentation in English; preserve localized application resources.

## Applications

- Organize by feature with predictable names. Start with a page; create files when responsibilities justify them.
- Keep purely visual state in the widget. Use the existing Cubit/controller or Riverpod framework for meaningful application workflows. Do not migrate state management as incidental cleanup.
- Put network, persistence, platform, and external-service operations behind repositories or existing adapters. Inject dependencies at composition boundaries.
- Add domain layers, use cases, separate DTOs, interfaces, and mappers only to isolate real contracts or logic. Do not create forwarding layers or speculative abstractions.
- Share code after a real shared responsibility emerges. Do not route every feature through a growing generic framework.
- Split files by responsibility and readability, not an arbitrary line limit or one-type-per-file rule. Related small state/model types can live together.
- Keep domain logic independent of UI and concrete integrations; `flutter/foundation.dart` annotations are allowed. UI SDKs (localization, navigation, observability widgets) belong in UI. Existing composition can be documented as a narrow boundary exception.

## Libraries and plugins

Preserve public APIs, rendering behavior, platform-channel payloads, native replies, declared SDK floors, and compatibility. Do not impose application layers, state managers, Saropa, or GTM runtime dependencies. Keep existing lightweight linting. Repository-only instructions and validation tooling must not enter published archives.

## Verification proportional to risk

| Change | Verification |
| --- | --- |
| Instructions/documentation | Local policy/skill checks; verify affected examples or commands |
| Cosmetic UI | Relevant analysis; visual inspection when useful; no automatic new tests |
| Business logic or regression | Focused behavioral tests for the changed contract |
| Important interaction | Targeted widget tests for input, navigation, state, and accessibility |
| Integration/protocol/native | Stable tests for affected surfaces; compile affected examples/platforms |
| Release | Explicit release lane, separate from everyday development |

Keep useful tests for authentication, purchases, account deletion, privacy, game rules, hidden information, multiplayer authorization, and SDK contracts. Do not demand tests for every class, state, view, or empty scaffold. No global coverage percentage is required; reports may remain useful. Do not delete meaningful assertions to get a green build.

Golden tests, stored image comparison baselines, and screenshot snapshot substitutes are prohibited. Manual or agent-assisted visual inspection is available without comparison baselines.

## Quality and drift prevention

Use the checked-in validation entry point. Application lint selection is a frozen, small correctness-focused subset derived from Saropa essential, with the dependency and effective native plugin pinned. Runtime tier/lane settings must be explicit where supported. Verify actual diagnostics when modifying the gate. A YAML include of `bloc_lint` is not an executed lint engine.

Boundary failures must name the import and suggest the correct existing boundary. Document narrow legitimate exceptions with their reason; do not blanket-disable the guard or suppress real regressions. Optional suggestions do not become a second blocking analysis gate. Do not introduce broad generated rule inventories or coverage/size/documentation quotas.

Run focused checks during iteration, and the stable affected-surface suites before integration. Record actual failures honestly; do not bypass protection or mask failures.

## Local skills and updates

Real files under `.agents/skills/` are tracked with the repository. Read only the relevant references. The manifest `.gtm/project_setup.yaml` records profile, package roots, selected skills, bundle version, and original hashes. Different hashes mean local customization, not failure. Reinstallation restores missing files only; changing existing foundation files is an explicit reviewed migration. Do not use `generate --force` to adopt an existing app.
