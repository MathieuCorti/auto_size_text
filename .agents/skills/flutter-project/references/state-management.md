# State and workflows

Keep the framework already used by this project. Lowjo uses Riverpod; Cubit applications retain Cubit. Libraries and plugins do not acquire application state managers.

Use widget-local state for selection, expansion, animation, and other purely visual interactions. Use a Cubit/controller/provider when a workflow coordinates meaningful operations or shared application state. Do not create one automatically for every screen or delegate every widget property to it.

Keep asynchronous ownership clear: cancel owned subscriptions, dispose owned controllers, avoid updates after disposal, and avoid stale results overwriting newer state. Model meaningful loading/error/success transitions when an operation requires them, not boilerplate states for static content. Preserve existing dependency injection; do not add a second service locator.

Test important transitions, failure/recovery, and race regressions. There is no requirement to test every representational state or forwarding method.
