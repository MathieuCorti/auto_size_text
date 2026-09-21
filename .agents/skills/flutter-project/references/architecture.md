# Architecture by responsibility

Applications use feature-first organization and the existing naming/routing conventions. A static screen can be one page. Related small state and model types may share a file.

- Widget: rendering and ephemeral interaction state.
- Cubit/controller/provider: meaningful application workflow and state transitions.
- Repository/adapter: network, storage, platform, or external-service boundary.
- Domain/use case/interface/DTO: optional; add only for a meaningful independent contract, policy, or mapping.

UI should not directly access storage or network clients. Data should not import presentation. Domain logic must not import UI or concrete data implementations. `flutter/foundation.dart` is allowed for annotations. Composition roots may wire features and integrations; UI-specific localization, routing, and observability helpers are legitimate UI dependencies.

Do not introduce an interface with a single forwarding implementation unless it protects an actual contract. Do not extract every widget, split each type, or use a line threshold as an architecture decision. Preserve useful existing abstractions and avoid broad refactors during a feature change.

Boundary exceptions in `.gtm/quality.json` name one importer, one import, the rule, and the architectural reason. Prefer fixing the responsibility over adding an exception. A project exception is not a reason to relax every project.
