import ApplicationServices

enum AX {
    static func copy(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        copy(element, attribute) as? String
    }

    static func bool(_ element: AXUIElement, _ attribute: String) -> Bool {
        copy(element, attribute) as? Bool ?? false
    }

    static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = copy(element, attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    static func elements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
        copy(element, attribute) as? [AXUIElement] ?? []
    }

    @discardableResult
    static func set(_ element: AXUIElement, _ attribute: String, _ value: Bool) -> AXError {
        AXUIElementSetAttributeValue(element, attribute as CFString, value as CFBoolean)
    }

    static func same(_ left: AXUIElement?, _ right: AXUIElement?) -> Bool {
        guard let left, let right else { return false }
        return CFEqual(left, right)
    }
}
