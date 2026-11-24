import AppKit
import ApplicationServices

@MainActor
struct FocusedText {
    var phrase = ""
    var bounds: CGRect?
    var application: NSRunningApplication?

    static func capture() -> Self {
        let application = NSWorkspace.shared.frontmostApplication
        var snapshot = Self(application: application)
        guard AXIsProcessTrusted(), let application,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return snapshot }

        let app = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.15)
        guard let focused = app.elementAttribute(kAXFocusedUIElementAttribute) else { return snapshot }
        AXUIElementSetMessagingTimeout(focused, 0.15)
        guard focused.attribute(kAXSubroleAttribute, as: String.self) != kAXSecureTextFieldSubrole else {
            return snapshot
        }

        snapshot.phrase = focused.attribute(kAXSelectedTextAttribute) ?? ""
        guard let range: CFTypeRef = focused.attribute(kAXSelectedTextRangeAttribute),
              CFGetTypeID(range) == AXValueGetTypeID() else { return snapshot }
        let rangeValue = range as! AXValue
        guard AXValueGetType(rangeValue) == .cfRange else { return snapshot }

        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            focused, kAXBoundsForRangeParameterizedAttribute as CFString, range, &value
        ) == .success, let value, CFGetTypeID(value) == AXValueGetTypeID() else { return snapshot }

        var rect = CGRect.zero
        guard AXValueGetValue(value as! AXValue, .cgRect, &rect),
              !rect.isNull, !rect.isInfinite, rect.height > 0,
              let primaryScreen = NSScreen.screens.first else { return snapshot }

        snapshot.bounds = CGRect(
            x: rect.minX, y: primaryScreen.frame.maxY - rect.maxY,
            width: rect.width, height: rect.height
        )
        return snapshot
    }
}
