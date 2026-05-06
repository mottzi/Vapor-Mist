import Vapor

extension Components {

    /// Resolves a registered component by its Swift type.
    func getComponent<C: Component>(ofType type: C.Type) -> C? {
        componentsByName.values.compactMap { $0 as? C }.first
    }

}
