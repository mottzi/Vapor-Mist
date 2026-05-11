# Mist

Server-driven UI for Swift, built on [Vapor](https://github.com/vapor/vapor). Mist renders components on the server and broadcasts HTML updates over WebSockets, patching the client DOM in real time. Build interactive web apps with zero custom JavaScript and no page reloads.

> [!WARNING]
> Early proof-of-concept — use in production with caution.

The Swift/Vapor ecosystem has no established equivalent to Rails [Hotwire/Turbo](https://hotwired.dev), Phoenix [LiveView](https://hexdocs.pm/phoenix_live_view/welcome.html), Laravel [Livewire](https://livewire.laravel.com), or [HTMX](https://htmx.org). Mist aims to fill that gap. Contributions and feedback are welcome — [open an issue](https://github.com/mottzi/Mist/issues/new) to get involved.

## Demo

Database records updated via HTTP GET — Mist detects the change, re-renders the component, and pushes the HTML to all connected clients instantly.

https://github.com/user-attachments/assets/6f9450a8-1abd-4b3c-a91b-f960ef53f606

## How It Works
 
A Mist component renders its template into updated HTML. Reactivity is governed by five protocols that dictate when re-rendering occurs. When triggered, Mist pushes the updated component HTML to all subscribed clients, where `mist.js` and `morphdom.js` patch the DOM.

| Protocol | Behavior |
| :--- | :--- |
| **`InstanceComponent`** | Binds to a database record.<br> Re-renders on create, update, or delete events. |
| **`QueryComponent`** | Binds to a database query.<br> Re-renders when the tracked model mutates. |
| **`PollingComponent`** | Periodically calls `poll()`.<br> Re-renders when the returned result changes. |
| **`LiveComponent`** | Periodically calls `refresh()`.<br> Re-renders when internal state changes. |
| **`ManualComponent`** | Fully manual. <br> Re-renders only when state is explicitly modified. |

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/mottzi/Mist", from: "0.20.0"),
],
targets: [
    .executableTarget(
        dependencies: [
            .product(name: "Mist", package: "Mist"),
        ]
    )
]
```

Copy `mist.js` and `morphdom.js` from the package into your `/Public` directory.

## Example

`CounterComponent` is a counter that all clients share and can increment; updates are seen instantly by everyone.

### Configure the Component

Define `count: Int` as the state of the component:

```swift
struct CounterState: ComponentData {

    var count: Int = 0

}
```

Define `CounterComponent` that conforms to the `ManualComponent` protocol. The initial `CounterState` is wrapped and managed by `LiveState`:

```swift
struct CounterComponent: ManualComponent {

    let state = LiveState(of: CounterState())

}
```

When the `LiveState` of a `ManualComponent` is `.set()` programmatically, the component re-renders using its template. Mist supports [Leaf](https://github.com/vapor/leaf.git) and [Elementary](https://github.com/elementary-swift/elementary.git) templates.

**Option A**: 

Define a Leaf template as an inline String: 

```swift
struct CounterComponent: ManualComponent {

    var template: any Template { LeafTemplate.inline("""
        <div mist-component="CounterComponent">
            <h2>Global Count</h2>
            <div>#(count)</div>
            <button mist-action="increment">Increment Count</button>
        </div>
        """)
    }

}
```

**Option B**: 

Reference a file based Leaf template:

```swift
struct CounterComponent: ManualComponent {

    // resolves to: /Resources/Views/CounterComponent.leaf
    var template: any Template { LeafTemplate.file("CounterComponent") }

    // resolves to: /Resources/Views/CounterComponent.leaf
    var template: any Template { LeafTemplate.file(self.name) }

}
```

If no template is explicitly defined, mist will use `LeafTemplate.file(self.name)` by default. Use `LeafTemplate.file("MyFolder/MyComponent")` when the `.leaf` file lives in a subfolder of `Resources/Views`.

**Option C**:

Elementary templates:

```swift
struct CounterComponent: ManualComponent {

    func body(state: CounterState) -> some HTML {
        div(.mistComponent(name), .mistDelay(100)) { // Throttles updates to 100ms
            h2 { "Global Count" }
            div { "\(state.count)" }
            button(.mistAction("increment")) { "Increment Count" }
        }
    }

}
```

### Add an Action

To make the button interactive, define `IncrementAction` that conforms to `Action`. Mist routes a client's click to the right server function by matching the `mist-action` attribute in the component template with the `name` property of the action. 

```swift
struct IncrementAction: Action {

    let name = "increment"
    let counterState: LiveState<CounterState>

    func perform(targetID: UUID?, state: inout ComponentState, app: Application) async -> ActionResult {
        let currentCount = await counterState.current.count
        await counterState.set(CounterState(count: currentCount + 1))
        return .success()
    }

}
```

The `perform()` function is called when a client clicks the increment button. It reads the current count, increments it, and sets the new state. This triggers a re-render and broadcast to all clients.

Add `IncrementAction` to `CounterComponent`:

```swift
struct CounterComponent: ManualComponent {

    var actions: [any Action] {
        [IncrementAction(counterState: state)]
    }

}
```

### Register the Component

Register the component with the Mist runtime:

```swift
try await app.mist.use {
    CounterComponent()
}
```

### Serve the Component

Now we just need to create a new route in our app that serves a HTML page containing our `CounterComponent`.

**Option A**:

Create a `.leaf` template file for `CounterComponent` at `Resources/Views/CounterComponent.leaf`:

```html
<div mist-component="CounterComponent">
    <h2>Global Count</h2>
    <div>#(count)</div>
    <button mist-action="increment">Increment Count</button>
</div>
```

Skip this if you are using an inline Leaf template.

Create a `.leaf` template file for the whole page at `/Resources/Views/CounterPage.leaf`. 

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <title>Counter Example Page</title>
</head>
<body>
    <div mist-container="CounterComponent" mist-ssr="true">
        #extend("CounterComponent")
    </div>
    <script src="/morphdom.js"></script>
    <script src="/mist.js"></script>
</body>
</html>
```

Leaf's `#extend` tag injects the `CounterComponent` into the page.

Serve the page, passing in the initial state so Leaf can populate the `#(count)` tag on the first load:

```swift
app.get("counter") { req async throws -> View in
    let counter = await req.application.mistComponent(CounterComponent.self)
    let currentState = await counter?.state.current ?? CounterState()
    return try await req.view.render("CounterPage", ["count": currentState.count])
}
```

**Option B**: Using Elementary

Then define the page using `HTMLDocument`:

```swift
// routes.swift — serve the page however you like; here using Elementary
import Elementary

struct CounterPage: HTMLDocument {
    
    var title = "Counter Example Page"
    let currentState: CounterState

    var head: some HTML { 
        EmptyHTML() 
    }

    var body: some HTML {
        div(
            .mistContainer(["CounterComponent"]),
            .mistSSR(true)
        ) {
            CounterComponent()
                .body(state: currentState)
        }
        script(.src("/morphdom.js")) {}
        script(.src("/mist.js")) {}
    }
    
}
```

Serve the page directly:

```swift
import VaporElementary

app.get("counter") { req async throws in
    let counter = await req.application.mistComponent(CounterComponent.self)
    let currentState = await counter?.state.current ?? CounterState()
    return HTMLResponse { CounterPage(currentState: currentState) }
}
```

That's it. Every connected client viewing the `/counter` page will now increment the same global counter and see every update instantly.

### Demo

Click [here](https://mottzi.codes/CounterExample) for a live demo.

https://github.com/user-attachments/assets/9bb1edfe-cd06-4ef1-af4d-53d452624d56

## Primitives

<details>
<summary><strong>InstanceComponent</strong></summary>

One rendered instance per database record. Mist listens to Fluent create/update/delete events and re-renders the matching instance for all subscribed clients.

```swift
struct PostComponent: InstanceComponent {
    let models: [any Mist.Model.Type] = [Post.self]
}
```

**Multi-model components** share a UUID primary key. Override `allModels(on:)` to control the initial data load: `allModels(on:)` returns rows of `models.first` (**one Mist instance per primary row**, e.g. each row is one `{User + Profile}` card); Mist loads every other listed type by the same primary key.

```swift
struct ProfileComponent: InstanceComponent {

    let division: String

    var name: String { Self.name(for: division) }

    let models: [any Mist.Model.Type] = [User.self, Profile.self]
    let template: any Template = LeafTemplate.file("TeamProfileExample/ProfileComponent")

    static func name(for division: String) -> String {
        "ProfileComponent-\(division)"
    }

    func allModels(on db: Database) async throws -> [any Mist.Model] {
        try await User.query(on: db)
            .filter(\.$division == division)
            .sort(\.$displayName)
            .all()
    }
}
```

Template context keys are the lowercased type names: `context.user`, `context.profile`.

**shouldUpdate** — filter which model changes trigger a re-render:

```swift
extension ProfileComponent {
    func shouldUpdate<M: Model>(for model: M) -> Bool {
        if model is Profile { return true }
        guard let user = model as? User else { return false }
        return user.division == division
    }
}
```

**Component template** — `Resources/Views/TeamProfileExample/ProfileComponent.leaf`

```html
<article class="profile-card"
         mist-component="ProfileComponent-#(context.user.division)"
         mist-id="#(context.user.id)">
    <header>
        <span class="name">#(context.user.displayName)</span>
        <span class="handle">@#(context.user.handle)</span>
    </header>
    <p class="bio">#(context.profile.bio)</p>
</article>
```

**Page template** — `Resources/Views/TeamProfileExample/TeamProfileExamplePage.leaf`

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <title>Team directory</title>
</head>
<body>
    <main class="container">
        <h1>Team directory</h1>
        <div class="profile-grid" mist-container="ProfileComponent-#(division)" mist-ssr="true">
            #for(context in contexts):
                #extend("TeamProfileExample/ProfileComponent")
            #endfor
        </div>
    </main>
    <script src="/morphdom.js"></script>
    <script src="/mist.js"></script>
</body>
</html>
```

**Route and registration** — Register **`ProfileComponent`** once per allowed `division`. `GET /teamprofile/:division` (e.g. `/teamprofile/myDivisionA21id`) rejects unknown segments so only registered names appear in the DOM.

```swift
let divisions = ["europe", "east-coast"]

try await app.mist.use {
    for division in divisions {
        ProfileComponent(division: division)
    }
}

app.get("teamprofile", ":division") { req async throws -> View in
    let division = try req.parameters.require("division")
    guard divisions.contains(division) else {
        throw Abort(.notFound)
    }
    let component = ProfileComponent(division: division)
    let componentContexts = try await component.makeContext(ofAll: req.db)
    let page = TeamDirectoryPageContext(contexts: componentContexts.contexts, division: division)
    return try await req.view.render("TeamProfileExample/TeamProfileExamplePage", page)
}

struct TeamDirectoryPageContext: Encodable {
    let contexts: [ModelContext]
    let division: String
}
```

**Elementary instance components** use the same model listener and delivery path, but render from a Swift context instead of `ModelContext`:

```swift
struct ProfileComponent: ElementaryInstanceComponent {
    typealias InstanceModel = User
    typealias TemplateContext = Context

    struct Context: Encodable {
        let user: User
        let profile: Profile
        let detailsExpanded: Bool
    }

    let division: String
    var name: String { Self.name(for: division) }
    let models: [any Mist.Model.Type] = [User.self, Profile.self]
    let defaultState: ComponentState = ["detailsExpanded": .bool(false)]

    static func name(for division: String) -> String {
        "ProfileComponent-\(division)"
    }

    func allInstances(on db: Database) async throws -> [User] {
        try await User.query(on: db)
            .filter(\.$division == division)
            .sort(\.$displayName)
            .all()
    }

    func makeTemplateContext(
        from user: User,
        state: ComponentState?,
        on db: Database
    ) async throws -> Context? {
        guard let id = user.id,
              let profile = try await Profile.find(id, on: db)
        else { return nil }

        return Context(
            user: user,
            profile: profile,
            detailsExpanded: state?["detailsExpanded"]?.bool ?? false
        )
    }

    func body(context: Context) -> some HTML {
        article(
            .mistComponent(name),
            .mistId(context.user.id?.uuidString ?? "")
        ) {
            header {
                span(.class("name")) { context.user.displayName }
                span(.class("handle")) { "@\(context.user.handle)" }
            }
            p { context.profile.bio }
        }
    }
}
```

For initial SSR, call `makeTemplateContexts(ofAll:)` and pass the resulting `[Context]` to the page you render with Elementary. Runtime create/update/delete delivery still uses the component registration and websocket path.

</details>

<details>
<summary><strong>QueryComponent</strong></summary>

A single fragment driven by a Fluent query. Re-renders when any tracked model changes.

```swift
struct LatestPostComponent: QueryComponent {
    typealias FragmentModel = Post

    func query(on db: Database) async throws -> Post? {
        try await Post.query(on: db).sort(\.$created, .descending).first()
    }
}
```

`query` returning `nil` sends a delete message — the fragment disappears from subscribed clients.

</details>

<details>
<summary><strong>PollingComponent</strong></summary>

Periodically calls `poll(on:)` and broadcasts when the result changes. No Fluent middleware involved.

```swift
struct VoteResultsComponent: PollingComponent {
    var refreshInterval: Duration { .seconds(2) }

    func poll(on db: Database) async -> VoteContext? {
        let swiftCount  = (try? await LiveVotingModel.query(on: db).filter(\.$choice == "swift").count())  ?? 0
        let kotlinCount = (try? await LiveVotingModel.query(on: db).filter(\.$choice == "kotlin").count()) ?? 0
        return VoteContext(swift: swiftCount, kotlin: kotlinCount)
    }
}
```

`poll` returning `nil` sends a delete message to all subscribed clients. New subscribers receive the last known state immediately without waiting for the next poll cycle.

</details>

<details>
<summary><strong>LiveComponent</strong></summary>

Owns a `LiveState` that it refreshes on a schedule. Call `state.set(…)` inside `refresh(app:)` — Mist broadcasts to all subscribers whenever the value actually changes.

```swift
struct SystemMemoryComponent: LiveComponent {
    struct SystemMetrics: ComponentData {
        var memoryUsage: Double
    }

    let state = LiveState(of: SystemMetrics(memoryUsage: getSystemMemoryUsageMB()))
    var refreshInterval: Duration { .seconds(2) }

    func refresh(app: Application) async {
        let usageMB = getSystemMemoryUsageMB()
        await state.set(SystemMetrics(memoryUsage: usageMB))
    }
}
```

`refresh(app:)` is called once at startup, then after each `refreshInterval`. Broadcasts only fire when the new value differs from the current one.

By default, `LiveComponent` sets `pausesDuringAction = true` — automatic refreshes are suppressed while an action is executing to prevent race conditions.

</details>

<details>
<summary><strong>ManualComponent</strong></summary>

Like `LiveComponent` but with no automatic refresh loop. You drive all updates yourself by calling `state.set(…)` from anywhere — actions, routes, background tasks.

```swift
struct CounterComponent: ManualComponent {
    struct State: ComponentData {
        var count = 0
    }

    let state = LiveState(of: State())
    var actions: [any Action] { [IncrementAction(counterState: state)] }
}
```

Push an update from an action, a route handler, or background work:

```swift
await counterComponent.state.set(CounterComponent.State(count: newCount))
```

</details>

<br>

<details>
<summary><strong>Actions</strong></summary>

Actions are server-side functions triggered by `mist-action` HTML attributes on click. They receive mutable per-client `ComponentState` and an optional `targetID`.

**Define:**

```swift
struct IncrementAction: Action {
    let name = "increment"
    let counterState: LiveState<CounterComponent.State>

    func perform(targetID: UUID?, state: inout ComponentState, app: Application) async -> ActionResult {
        let current = await counterState.current.count
        await counterState.set(.init(count: current + 1))
        return .success()
    }
}
```

**Register on the component:**

```swift
struct CounterComponent: ManualComponent {
    let state = LiveState(of: State())
    var actions: [any Action] { [IncrementAction(counterState: state)] }
}
```

**Trigger from the template:**

```html
<button mist-action="increment">+</button>
```

**Return values:**

```swift
return .success()                     // success, no message
return .success("Deployment started") // success with message
return .failure("Not found")          // failure with message
```

The client receives an `actionResult` message regardless. On `.success`, Mist automatically re-renders the component instance for the acting client with updated state.

**Actions for detached controls** — trigger an action on a component elsewhere in the DOM using `mist-actions-for`:

```html
<button mist-action="stop" mist-actions-for="StatusComponent-myapp">Stop</button>
```

</details>

<details>
<summary><strong>Streams</strong></summary>

Append-only text streams scoped to a component instance. Useful for streaming build output, logs, or LLM token responses. The buffer is snapshotted and replayed to new subscribers automatically.

**Server:**

```swift
// Replace the full stream content
await app.mist.streams.replace(component: "RowComponent-myapp", modelID: id, stream: "build-output", text: fullLog)

// Append a chunk
await app.mist.streams.append(component: "RowComponent-myapp", modelID: id, stream: "build-output", text: chunk)

// Close the stream (clears the buffer)
await app.mist.streams.close(component: "RowComponent-myapp", modelID: id, stream: "build-output")
```

**Template:**

```html
<pre mist-stream="build-output"></pre>
```

The `[mist-stream]` element receives text directly. `append` appends a text node; `replace` sets `textContent`. The element auto-scrolls to the bottom on each update.

</details>

<br>

<details>
<summary><strong>Per-Client State</strong></summary>

`ComponentState` is a `[String: ComponentValue]` dictionary scoped to one client × one component instance. It persists across actions and is passed into every render for that client, so templates can reflect each client's individual state.

```swift
// Read and mutate inside an action
func perform(targetID: UUID?, state: inout ComponentState, app: Application) async -> ActionResult {
    let isExpanded = state["detailsExpanded"]?.bool ?? false
    state["detailsExpanded"] = .bool(!isExpanded)
    return .success()
}
```

Declare defaults on the component:

```swift
let defaultState: ComponentState = ["detailsExpanded": .bool(false)]
```

`ComponentValue` supports `.bool(Bool)`, `.string(String)`, and `.int(Int)`.

Access in a Leaf template:

```html
#if(state.detailsExpanded):
    <div class="expanded-content">...</div>
#endif
```

</details>

<details>
<summary><strong>Computed Properties</strong></summary>

Models can expose computed values that are merged into the template context alongside stored fields:

```swift
final class Deployment: Mist.Model, Content {
    // ... stored fields ...

    var computedProperties: [String: any Encodable] {[
        "shortID":       String(id?.uuidString.prefix(8) ?? ""),
        "durationString": formattedDuration(),
        "canBeDeployed":  status == "pushed"
    ]}
}
```

These appear in the Leaf template just like regular fields: `#(context.deployment.shortID)`.

</details>

<details>
<summary><strong>Client Attributes</strong></summary>

| Attribute | Purpose |
|---|---|
| `mist-component="Name"` | Marks a component root; used for DOM targeting and subscriptions |
| `mist-id="uuid"` | Instance identity for `InstanceComponent` |
| `mist-ssr="true"` | Marks a component as SSR-ready to optimize initial connection |
| `mist-delay="ms"` | Throttles component updates by the specified millisecond delay |
| `mist-container="Name"` | Accepts dynamically inserted/removed component instances |
| `mist-insert-position` | Where new instances are inserted — any `insertAdjacentHTML` position, default `beforeend` |
| `mist-action="actionName"` | Triggers a server action on click |
| `mist-actions-for="Name"` | Routes a click action to a named component elsewhere in the DOM |
| `mist-stream="streamName"` | Receives append-only text from the server |
| `mist-behavior="timer"` | Client-side elapsed timer, requires `data-started-at-unix-ms` |
| `mist-behavior="local-datetime"` | Formats a Unix ms timestamp to local time, requires `data-started-at-unix-ms` |
| `mist-behavior="sortable-collection"` | Auto-sorts children by `data-mist-sort-value` on mutation |
| `data-mist-sort-order` | `"asc"` (default) or `"desc"` |
| `data-mist-sort-type` | `"number"` (default) or `"string"` |
| `data-mist-sort-delay-ms` | Debounce delay in ms before reordering (default `0`) |

</details>

<details>
<summary><strong>Socket Configuration</strong></summary>

```swift
// Custom WebSocket path (default: /mist/ws/)
app.mist.socket.path = ["deployer", "ws"]

// Attach auth middleware to the socket endpoint
app.mist.socket.middleware = MySessionAuthMiddleware()

// Custom upgrade validation — return nil to reject the upgrade
app.mist.socket.shouldUpgrade = { request async -> HTTPHeaders? in
    guard request.session.data["admin_auth"] == "true" else { return nil }
    return HTTPHeaders()
}
```

</details>

## Examples

Interactive demos run at [Mist Examples](https://mottzi.codes/MistExamples). Full sources live in [Vapor-Mist-examples](https://github.com/mottzi/Vapor-Mist-examples); routes are registered in [`Sources/Mottzi/MistExamples/MistExamples.swift`](https://github.com/mottzi/Vapor-Mist-examples/blob/main/Sources/Mottzi/MistExamples/MistExamples.swift) .

<details>
<summary><strong>Flashcards</strong></summary>

Shows `InstanceComponent` with paired Fluent models whose rows share one UUID, Leaf markup for each card, per-client flip state, plus actions to create random pairs, shuffle text, and delete both sides. New rows hydrate into the grid via a `mist-container`.

- **Live demo:** [Flashcards](https://mottzi.codes/FlashcardExample)
- **Code:** [`Sources/Mottzi/MistExamples/FlashCardExample`](https://github.com/mottzi/Vapor-Mist-examples/tree/main/Sources/Mottzi/MistExamples/FlashCardExample)
- **Leaf templates:** [`Resources/Views/FlashcardExample`](https://github.com/mottzi/Vapor-Mist-examples/tree/main/Resources/Views/FlashcardExample)

</details>

<details>
<summary><strong>Counter</strong></summary>

Single shared counter implemented as `ManualComponent`: one `LiveState`, an increment action, Elementary-built markup. Updates broadcast so every browser stays aligned without polling.

- **Live demo:** [Counter](https://mottzi.codes/CounterExample)
- **Code:** [`Sources/Mottzi/MistExamples/CounterExample`](https://github.com/mottzi/Vapor-Mist-examples/tree/main/Sources/Mottzi/MistExamples/CounterExample)

</details>

<details>
<summary><strong>Counter (Leaf)</strong></summary>

Same counter semantics as above with Leaf supplying the page shell—useful if you want to compare Mist wiring alongside traditional server-rendered HTML.

- **Live demo:** [Counter (Leaf)](https://mottzi.codes/CounterExample2)
- **Code:** [`Sources/Mottzi/MistExamples/CounterExample2`](https://github.com/mottzi/Vapor-Mist-examples/tree/main/Sources/Mottzi/MistExamples/CounterExample2)

</details>

<details>
<summary><strong>System monitor</strong></summary>

Several `LiveComponent` tiles on one dashboard-style page (memory, CPU, websocket client count, stress harness). Mist invokes each fragment's `refresh(app:)` on its interval so numbers stay current without user gestures.

- **Live demo:** [System monitor](https://mottzi.codes/SystemMonitorExample)
- **Code:** [`Sources/Mottzi/MistExamples/SystemMemoryExample`](https://github.com/mottzi/Vapor-Mist-examples/tree/main/Sources/Mottzi/MistExamples/SystemMemoryExample) · per-widget Swift under [`Components`](https://github.com/mottzi/Vapor-Mist-examples/tree/main/Sources/Mottzi/MistExamples/SystemMemoryExample/Components)

</details>

<details>
<summary><strong>Live polling / voting</strong></summary>

`PollingComponent` for a Swift vs Kotlin straw poll: vote actions append Fluent rows; `poll(on:)` runs on an interval to re-count choices and push refreshed percentages and totals to every subscriber.

- **Live demo:** [Live polling / voting](https://mottzi.codes/LivePollingExample)
- **Code:** [`Sources/Mottzi/MistExamples/LivePollingExample`](https://github.com/mottzi/Vapor-Mist-examples/tree/main/Sources/Mottzi/MistExamples/LivePollingExample)

</details>

<details>
<summary><strong>Deployer panel</strong></summary>

Production-grade Mist UI over Fluent-backed deployments: parameterised `InstanceComponent` rows, `LiveComponent` queue lock and process badges, `ManualComponent` config summary, streamed build logs through `mist-stream`, strict websocket upgrade checks, and per-client expansion state for logs—not bundled with Vapor-Mist-examples.

- **Project:** [Vapor-Deployer](https://github.com/mottzi/Vapor-Deployer)
- **Code:** Mist-specific Swift under [`Sources/Deployer/Panel`](https://github.com/mottzi/Vapor-Deployer/tree/main/Sources/Deployer/Panel)
- **Leaf templates:** [`Resources/Views/Deployer`](https://github.com/mottzi/Vapor-Deployer/tree/main/Resources/Views/Deployer)

</details>
