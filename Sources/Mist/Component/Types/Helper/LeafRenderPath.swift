import Vapor

/// A sentinel type that signifies a component relies on Leaf for rendering instead of an Elementary body.
/// This prevents collisions with protocol extensions since it does not conform to `Elementary.HTML`.
public struct LeafRenderPath: Sendable {}
