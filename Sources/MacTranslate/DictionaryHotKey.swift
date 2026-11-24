import Carbon
import Observation
import OSLog

@MainActor
@Observable
final class DictionaryHotKey {
    private(set) var registrationError: OSStatus?

    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private var onPress: (() -> Void)?

    func start(onPress: @escaping () -> Void) {
        guard eventHandler == nil else { return }

        self.onPress = onPress
        let target = GetApplicationEventTarget()
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(
            target, Self.handlePress, 1, &eventType,
            Unmanaged.passUnretained(self).toOpaque(), &eventHandler
        )
        guard handlerStatus == noErr else {
            reportFailure(handlerStatus)
            return
        }

        let modifiers = UInt32(controlKey | optionKey | shiftKey | cmdKey)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_D), modifiers, Self.identifier, target, UInt32(kEventHotKeyExclusive), &hotKey
        )
        if status == noErr {
            registrationError = nil
        } else {
            stop()
            reportFailure(status)
        }
    }

    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        hotKey = nil
        eventHandler = nil
        onPress = nil
    }

    private func reportFailure(_ status: OSStatus) {
        registrationError = status
        Logger(subsystem: Bundle.main.bundleIdentifier ?? "MacTranslate", category: "Shortcuts")
            .error("Could not register Hyper+D (OSStatus: \(status))")
    }

    private nonisolated static var identifier: EventHotKeyID {
        EventHotKeyID(signature: 0x4D545244, id: 1) // MTRD
    }

    private nonisolated static let handlePress: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else { return OSStatus(eventNotHandledErr) }
        var identifier = EventHotKeyID()
        let status = GetEventParameter(
            event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
            nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier
        )
        guard status == noErr, identifier.signature == DictionaryHotKey.identifier.signature,
              identifier.id == DictionaryHotKey.identifier.id else { return OSStatus(eventNotHandledErr) }

        let hotKey = Unmanaged<DictionaryHotKey>.fromOpaque(userData).takeUnretainedValue()
        MainActor.assumeIsolated { hotKey.onPress?() }
        return noErr
    }
}
