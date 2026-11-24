import ApplicationServices

extension AXUIElement {
    func attribute<Value>(_ name: String, as type: Value.Type = Value.self) -> Value? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, name as CFString, &value) == .success else { return nil }
        return value as? Value
    }

    func elementAttribute(_ name: String) -> AXUIElement? {
        guard let value: CFTypeRef = attribute(name), CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        // The Core Foundation type check above establishes the concrete type.
        return (value as! AXUIElement)
    }
}
