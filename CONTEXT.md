# Mist Context

## Domain Terms

- **Mist runtime**: The server-side runtime attached to a Vapor `Application` through `app.mist`.
- **Component**: A renderable unit registered with the Mist runtime and addressed by its runtime name.
- **Fragment component**: A component addressed and updated as a single fragment rather than as model instances.
- **Instance component**: A model-backed component addressed by a shared component ID, currently a `UUID`.
- **Query component**: A fragment component whose current render state is selected from a Fluent query.
- **Component state**: Per-client mutable state used while rendering actions or interactive component instances.
- **Component delivery**: The Mist runtime step that turns render results into client-visible effects such as fragment updates, fragment deletes, instance creates, instance updates, and instance deletes.
- **Subscription**: A client's declared interest in receiving updates for a component name.
- **Stream**: Append-only text content scoped to a component instance and replayed to new subscribers.
