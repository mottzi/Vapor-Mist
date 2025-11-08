# Mist Macro Usage Guide

## Overview

Mist provides Swift macros to automatically generate `contextExtras()` implementations for your models. This eliminates boilerplate and makes it trivial to add computed properties to your template contexts.

The `@ExtraContext` attribute is a marker macro that works with `@ExtraContextProvider` to identify which computed properties should be included in the template context.

## Requirements

- Swift 6.0+
- macOS 13+

## Basic Usage

### 1. Mark Your Model with `@ExtraContextProvider`

Apply the `@ExtraContextProvider` macro to any model that needs automatic context extras:

```swift
import Mist
import Fluent
import Vapor

@ExtraContextProvider
final class Article: Model {
    static let schema = "articles"
    
    @ID(key: .id) var id: UUID?
    @Field(key: "title") var title: String
    @Field(key: "content") var content: String
    @Field(key: "views") var views: Int
    @Field(key: "created_at") var createdAt: Date
}
```

### 2. Add Extra Context Properties with `@ExtraContext`

Mark any computed properties you want included in the template context:

```swift
@ExtraContextProvider
final class Article: Model {
    static let schema = "articles"
    
    @ID(key: .id) var id: UUID?
    @Field(key: "title") var title: String
    @Field(key: "content") var content: String
    @Field(key: "views") var views: Int
    @Field(key: "created_at") var createdAt: Date
    
    // These will be automatically included in contextExtras()
    @ExtraContext var titleUpper: String {
        title.uppercased()
    }
    
    @ExtraContext var isPopular: Bool {
        views > 1000
    }
    
    @ExtraContext var previewText: String {
        String(content.prefix(100)) + "..."
    }
    
    @ExtraContext var daysOld: Int {
        Calendar.current.dateComponents(
            [.day], 
            from: createdAt, 
            to: Date()
        ).day ?? 0
    }
}
```

### 3. Use in Templates

All `@ExtraContext` properties are automatically available in your Leaf templates:

```html
<article>
    <h1>#(article.titleUpper)</h1>
    <p class="preview">#(article.previewText)</p>
    
    #if(article.isPopular):
        <span class="badge">🔥 Popular</span>
    #endif
    
    <time>Posted #(article.daysOld) days ago</time>
    <div class="stats">Views: #(article.views)</div>
</article>
```

## What Gets Generated

The `@ExtraContextProvider` macro generates the `contextExtras()` method automatically:

```swift
// You write this:
@ExtraContextProvider
final class Article: Model {
    @Field(key: "title") var title: String
    
    @ExtraContext var titleUpper: String {
        title.uppercased()
    }
}

// The macro generates:
func contextExtras() -> [String: any Encodable] {
    var extras: [String: any Encodable] = [:]
    extras["titleUpper"] = titleUpper
    return extras
}
```

## Advanced Examples

### Computed Properties with Complex Logic

```swift
@ExtraContextProvider
final class User: Model {
    static let schema = "users"
    
    @ID(key: .id) var id: UUID?
    @Field(key: "first_name") var firstName: String
    @Field(key: "last_name") var lastName: String
    @Field(key: "email") var email: String
    @Field(key: "role") var role: String
    @Field(key: "created_at") var createdAt: Date
    
    @ExtraContext var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    @ExtraContext var initials: String {
        let first = firstName.first.map(String.init) ?? ""
        let last = lastName.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
    
    @ExtraContext var isAdmin: Bool {
        role == "admin" || role == "superadmin"
    }
    
    @ExtraContext var gravatarUrl: String {
        let hash = email.lowercased().data(using: .utf8)?.md5 ?? ""
        return "https://www.gravatar.com/avatar/\(hash)"
    }
    
    @ExtraContext var membershipDays: Int {
        Calendar.current.dateComponents(
            [.day],
            from: createdAt,
            to: Date()
        ).day ?? 0
    }
}
```

### Working with Relationships

```swift
@ExtraContextProvider
final class BlogPost: Model {
    static let schema = "posts"
    
    @ID(key: .id) var id: UUID?
    @Field(key: "title") var title: String
    @Parent(key: "author_id") var author: User
    @Children(for: \.$post) var comments: [Comment]
    
    @ExtraContext var authorName: String {
        // Note: Only use this if author is already eager-loaded
        author.firstName + " " + author.lastName
    }
    
    @ExtraContext var commentCount: Int {
        // Note: Only use this if comments are already eager-loaded
        comments.count
    }
}
```

## Best Practices

### ✅ DO

- Use `@ExtraContext` for derived/computed values
- Keep computations lightweight (no DB queries)
- Use for formatting, concatenation, simple calculations
- Combine with eager loading for relationship-based extras

### ❌ DON'T

- Don't perform database queries in `@ExtraContext` properties
- Don't make network requests
- Don't access relationships unless they're eager-loaded
- Don't perform expensive computations

### Note on Property Wrappers

`@ExtraContext` is **not** a property wrapper - it's an attribute macro that serves as a marker. You can use it on computed properties without any special syntax. The macro simply identifies which properties to include in `contextExtras()`.

## Migration from Manual `contextExtras()`

### Before (Manual Implementation)

```swift
final class Article: Model {
    @Field(key: "title") var title: String
    @Field(key: "views") var views: Int
    
    func contextExtras() -> [String: any Encodable] {
        return [
            "titleUpper": title.uppercased(),
            "isPopular": views > 1000
        ]
    }
}
```

### After (Using Macros)

```swift
@ExtraContextProvider
final class Article: Model {
    @Field(key: "title") var title: String
    @Field(key: "views") var views: Int
    
    @ExtraContext var titleUpper: String {
        title.uppercased()
    }
    
    @ExtraContext var isPopular: Bool {
        views > 1000
    }
}
```

## Benefits

1. **Type Safety**: Computed properties have explicit types, catching errors at compile time
2. **Less Boilerplate**: No manual dictionary construction
3. **Better Autocompletion**: IDEs can suggest property names and types
4. **Maintainability**: Clear separation of regular fields and computed extras
5. **Performance**: Lazy evaluation only when accessed
6. **Testability**: Computed properties can be unit tested independently

## Viewing Generated Code

To see what code the macro generates, use Swift's expansion tool:

```bash
swift build
swift build --target Mist -Xswiftc -emit-macro-expansion-files
# Look in .build/<platform>/debug/Mist.build/Mist.swift
```

Or in Xcode, right-click on `@ExtraContextProvider` and select "Expand Macro".

## Troubleshooting

### Macro Not Found

Ensure your `Package.swift` includes the `MistMacros` dependency and SwiftSyntax is properly resolved:

```bash
swift package resolve
swift build
```

### Properties Not Appearing in Templates

1. Verify the property is marked with `@ExtraContext`
2. Ensure the type conforms to `@ExtraContextProvider`
3. Check that the property type is `Encodable`
4. Rebuild your project to regenerate macro expansions

### Compiler Errors

- Make sure you're using Swift 6.0+
- Verify all `@ExtraContext` properties return `Encodable` types
- Check that `@ExtraContextProvider` is only on classes or structs

## Performance Considerations

The macro generates code at **compile time**, so there's zero runtime overhead for the code generation itself. The only runtime cost is:

1. Evaluating the computed properties (when accessed)
2. Adding them to the dictionary in `contextExtras()`

This is typically faster than the previous JSON-merging approach since values are computed lazily and stored directly.

## Comparison with Manual Implementation

| Feature | Manual `contextExtras()` | Macro Approach |
|---------|-------------------------|----------------|
| Boilerplate | High | Minimal |
| Type Safety | Dictionary-based | Property-based |
| Autocomplete | Limited | Full IDE support |
| Refactoring | Manual updates | Automatic |
| Compile-time Validation | Partial | Complete |
| Runtime Overhead | Dictionary + JSON merge | Direct dictionary |
| Learning Curve | Low | Moderate |

---

**Next Level Swift** 🚀

This macro system represents modern Swift best practices, leveraging the language's most advanced metaprogramming features to deliver a delightful developer experience.

