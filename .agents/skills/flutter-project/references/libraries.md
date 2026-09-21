# Library and plugin contracts

Keep the public API, rendering semantics, supported SDK floors, and existing lightweight analysis. Do not import application layering, state management, Saropa, or GTM runtime dependencies into a library just to match an app profile.

For widget libraries, preserve constraint handling, text metrics, scaling, accessibility, and min/high SDK tests. Rendering assertions can inspect sizes and behavior without stored image comparisons.

For plugins, preserve channel names, argument keys/types, serialization, result/error semantics, native reply completion, and platform compatibility. Compile the affected example/native/web surface when changing its implementation or build tooling. Do not silently upgrade native SDKs or raise package minimums as a tooling workaround.

Keep development instructions, local skills, and repository-only tools out of package archives. API/version/publication changes require their own explicit scope.
