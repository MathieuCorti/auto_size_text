---
name: flutter-project
description: Implement, review, and maintain Dart or Flutter changes in this repository using its local lean engineering profile. Use for application, widget-library, plugin, architecture, and testing work; preserve the current framework and verify only the affected contracts.
---

# Project-local Flutter engineering

1. Read root `AGENTS.md`, `.gtm/engineering_policy.md`, and `.gtm/quality.json`. They identify this project's profile and commands. Do not search global Flutter skills for competing policy.
2. Identify the affected responsibility and existing pattern before adding files. Preserve unrelated work.
3. Load only references relevant to the task:
   - Structure, dependencies, or new features: [architecture](references/architecture.md).
   - State or workflows: [state management](references/state-management.md).
   - Tests or verification decisions: [testing](references/testing.md).
   - Public packages or native bridges: [library and plugin contracts](references/libraries.md).
4. Implement the smallest coherent change; retain meaningful existing integration boundaries. Do not invent layers, interfaces, DTOs, or tests merely to match a template.
5. Run local policy/boundary checks and affected analysis, then focused tests according to risk. Report what ran and any unverified platform explicitly.

There are no golden tests, stored visual baselines, global coverage quotas, mandatory line limits, or tests-per-type requirements. All technical deliverables are English; localized app resources remain localized.

This is a project-owned copy of GTM foundation 0.4.0. Edit locally when the project needs it. Installation never overwrites local customization.
