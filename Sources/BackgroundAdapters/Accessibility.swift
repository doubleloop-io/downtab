import ApplicationServices

/// Every Accessibility message to another app gives up after the same timeout: a busy or frozen app must not hold
/// its caller longer.
enum Accessibility {
    static let messagingTimeout: Float = 0.25

    static func application(_ pid: pid_t) -> AXUIElement {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        return element
    }
}

enum AXAttribute {
    static func copy(of element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
    }

    static func string(of element: AXUIElement, _ attribute: String) -> String? {
        copy(of: element, attribute) as? String
    }

    static func bool(of element: AXUIElement, _ attribute: String) -> Bool {
        copy(of: element, attribute) as? Bool ?? false
    }
}
