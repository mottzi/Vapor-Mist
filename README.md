# Mist
 
Mist is a lightweight Swift server components extension for [Vapor](https://docs.vapor.codes) applications. It enables real-time client side HTML component updates through type safe web socket communication with the server. 

[Fluent](https://docs.vapor.codes/fluent/overview/) is used as database ORM and [Leaf](https://docs.vapor.codes/leaf/overview/) is used as HTML templating engine - both are part of Vapor's default stack.

> [!WARNING]
> This is just a proof of concept implementation and not at all production ready!

AFAIK, the Swift/Vapor ecosystem does not currently have an equivalent to Ruby on Rails [Hotwire/Turbo](https://hotwired.dev), Phoenix [LiveView](https://hexdocs.pm/phoenix_live_view/welcome.html) or Laravel [Livewire](https://livewire.laravel.com), [HTMX](https://htmx.org) etc. The end goal of this project is to make Mist a usefull equivalent to those tools, but for the Swift / Vapor ecosystem!

Please consider using your Swift skills to contribute to Mist in whatever ways you can, as this project will only go as far as the community takes it! If you have suggestions or criticism, feel free to [open an issue](https://github.com/mottzi/Mist/issues/new)!

## Demo

The video below demonstrates Mist's real-time update capability: When database entries are modified, the changes are automatically detected and broadcasted to all connected clients. 

In this demo, we trigger database updates using simple HTTP GET requests to specific endpoints. When these endpoints are called, the server updates the corresponding database records, which Mist automatically detects. 

The system then renders the updated component HTML and pushes it through WebSockets to all subscribed clients, where the DOM is instantly updated without requiring a page refresh.

Keep an eye on the incoming update-messages in the browser's console!

https://github.com/user-attachments/assets/6f9450a8-1abd-4b3c-a91b-f960ef53f606

## Setup

### 1. Add package dependency (Package.swift):
```swift
let package = Package(
	...
    dependencies: [
        .package(url: "https://github.com/mottzi/Mist", from: "0.5.0"),
    ],
    targets: [
        .executableTarget(
            ...
            dependencies: [
                .product(name: "Mist", package: "Mist"),
                ...
            ]
        )
    ]
)
```
Mist has Vapor, Fluent and Leaf declared as internal dependencies.

### 2. Define database table and model:

```swift
import Vapor
import Fluent
import Mist

final class DummyModel1: Mist.Model, Content
{
    static let schema = "dummymodel1"
    
    @ID(key: .id) 
    var id: UUID?
    
    @Field(key: "text") 
    var text: String
    
    @Timestamp(key: "created", on: .create) 
    var created: Date?
    
    init() {}
    init(text: String) { self.text = text }
}

extension DummyModel1
{
    struct Table: AsyncMigration
    {
        func prepare(on database: Database) async throws
        {
            try await database.schema(DummyModel1.schema)
                .id()
                .field("text", .string, .required)
                .field("created", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws
        {
            try await database.schema(DummyModel1.schema).delete()
        }
    }
}
```
Do the same with DummyModel2...

### 3. Define server component:

> [!WARNING]
> The current implementation only supports one-to-one component model relationships in multi model components. Mist will implicitly use a model's ```id: UUID``` property  as identifier (```model1.id == model2.id```).

```swift
import Mist

struct DummyComponent: Mist.Component
{
    static let models: [any Mist.Model.Type] = [
        DummyModel1.self,
        DummyModel2.self
    ]
}
```

### 4. Add component template: 

File *Resources/Views/DummyComponent.leaf*:

```html
<tr mist-component="DummyComponent" mist-id="#(component.dummymodel1.id)">
    <td>#(component.dummymodel1.id)</td>
    <td>#(component.dummymodel1.text)</td>
    <td>#(component.dummymodel2.text)</td>
</tr>

```

### 5. Add template for initial page request:

File *Resources/Views/InitialDummies.leaf*:

```html
<!DOCTYPE html>
<html>
<head>
    <style>
        th, td { padding: 0 15px; }
    </style>
</head>
<body>
    <table>
        <thead>
            <tr>
                <th>Component ID</th>
                <th>DummyModel1</th>
                <th>DummyModel2</th>
            </tr>
        </thead>
        <tbody>
        #for(component in components):
            #extend("DummyComponent")
        #endfor
        </tbody>
    </table>

    <script src="/mist.js"></script>
</body>
</html>
```

### 6. Add route for initial page request:

File *Sources/App/routes.swift*:

```swift
app.get("DummyComponents")
{ request async throws -> View in
    // create template context with all available component data
    let context = await DummyComponent.makeContext(ofAll: request.db)

    // render initial page template with full data set
    return try await request.view.render("InitialDummies", context)
}
```

For demo purposes, add an endpoint to update component model data in database:

```swift
app.get("DummyModel1", "update", ":id", ":text")
{ req async throws -> HTTPStatus in
    
    guard let idString = req.parameters.get("id"),
          let id = UUID(uuidString: idString)
    else { throw Abort(.badRequest, reason: "Valid UUID required") }
    
    guard let text = req.parameters.get("text")
    else { throw Abort(.badRequest, reason: "Valid text required") }
    
    guard let dummyModel1 = try await DummyModel1.find(id, on: req.db)
    else { throw Abort(.notFound, reason: "DummyModel1 not found") }
    
    dummyModel1.text = text
    try await dummyModel1.save(on: req.db)
    
    return .ok
}
```

Do the same for DummyModel2...

### 7. Configure Mist:

File *Sources/App/configure.swift*:

```swift
// needed to serve mist.js to client
app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

// create component model database tables
app.migrations.add(
    DummyModel1.Table(),
    DummyModel2.Table()
)
 
// define Mist configuration
let config = Mist.Configuration(
    for: app,
    components: [
        DummyComponent.self,
    ]
)

// initialize Mist with configuration
await Mist.configure(using: config)
```

For demo purposes, create component models after configuration:

```swift
let dummyModel1 = DummyModel1(text: "Hello")
let dummyModel2 = DummyModel2(text: "World")

let componentID = UUID()
dummyModel1.id = componentID
dummyModel2.id = componentID

try await dummyModel1.save(on: app.db)
try await dummyModel2.save(on: app.db)
```

### 8. Copy mist.js to your public directory

The Mist framework package contains a [mist.js file](Sources/Mist/mist.js)) that handles client side DOM manipulation.

Simply copy this file to your application's /Public directory.

## Documentation

### Overview

**Current Features**:

- Server-defined components with automatic model binding
- Database change detection via Fluent middleware
- Automatic WebSocket-based HTML updates to connected clients
- Component subscription system
- Support for single and multi-model components (with shared UUID)
- Simple client-side DOM replacement with minimal JS

**Implementation Details**:

- Type-safe component registration using protocols ([MistComponent.swift](Sources/Mist/MistComponent.swift))
- Actor-based client and component registries for thread safety ([MistClients.swift](Sources/Mist/MistClients.swift), [MistComponents.swift](Sources/Mist/MistComponents.swift))
- Fluent database listener middleware configuration ([MistListener.swift](Sources/Mist/MistListener.swift))
- Leaf template rendering for component HTML generation ([MistComponent.swift](Sources/Mist/MistComponent.swift))
- JSON-based message protocol for communication over websockets ([MistSocket.swift](Sources/Mist/MistSocket.swift), [MistMessage.swift](Sources/Mist/MistMessage.swift))

**Known Limitations**:

- Only supports one-to-one relationships between component models via ```ìd: UUID```
- No differential updates (sends complete HTML on each change)
- Error handling
- No form binding or user input handling yet
- Testing architecture is in place but coverage is limited
- No security hardening applied yet

**Next Steps**:

- Support more complex model relationships
- Add form handling capabilities
- Implement optimized differential updates
- Improve connection stability and error recovery
- Expand documentation and examples
- Add authentication integration

**Project files**:

This prototype contains eight .swift and one .js file:

```swift
// Mist.swift:              entry point, configuration, initialization
// MistClients.swift:       central client registry, messaging
// MistComponents.swift:    central component registry

// MistComponent.swift:     context generation, html rendering
// MistModel.swift:         context generation
// MistListener.swift:      database update detection, messaging

// MistSocket.swift:        web socket server, handles client component subscriptions
// MistMessage.swift:       type safe client-server-client communication over web sockets
```

```swift
// mist.js:                 client-side DOM updates
```

### Data Flow Charts

I created some flow charts that visualize the data flow in important parts of Mist:

<details>
<summary>1. Initial Page Request</summary>
	
![Initial](https://mottzi.de/space/mist0.svg?)

1. Client requests initial full page
2. Server fetches necessary data from database
3. Server creates template context
4. Server renders full page
5. Server sends initial HTML (including mist.js) to client

</details>

<details>
<summary>2. Component Subscription</summary>
	
![Initial](https://mottzi.de/space/mist-sub1.svg?)

1. Client uses mist.js to connect to server through web socket
2. Server adds the connected client to registry
3. Client scans DOM for "mist-component" HTML attribute
4. Client sends subscription messages of found components
5. Server adds subscriptions to client inside of registry

</details>

<details>
<summary>3. Component Update Broadcasting</summary>
	
![Initial](https://mottzi.de/space/mist-listener.svg?)

1. Server registers middleware listeners for each model
2. Database model entry changes
3. Mist.Listener for that model triggers
4. Server identifies components using changed model
5. Server re-renders affected components and creates update messages
6. Server identifies clients that are subscribed to these components
7. Server broadcasts update messages to subscribed clients

</details>

<details>
<summary>4. Client Update Handling</summary>
	
![Initial](https://mottzi.de/space/mist-update.svg?)

1. Client receives update message using mist.js
2. Client parses received JSON payload
3. Client scans DOM to find elements with matching component name and id
4. Client replaces outerHTML of found component with update

</details>
