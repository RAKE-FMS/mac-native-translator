import Foundation
import Observation
import Translation

@MainActor
@Observable
final class TranslationPanelModel {
    private static let modePreferenceKey = "translationMode"

    let languageOptions: [TranslationLanguage]

    private(set) var direction: TranslationDirection?
    private(set) var availableModes: [TranslationMode] = []
    private(set) var selectedMode: TranslationMode
    private(set) var isCheckingModes = false
    private(set) var isTranslating = false
    private(set) var message: String?
    private(set) var modeNotice: String?
    private(set) var translationConfiguration: TranslationSession.Configuration?

    private let translator: FoundationTranslator
    private let modeAvailability: TranslationModeAvailability
    private var activeOperation = UUID()
    private var activeTranslationTask: Task<Void, Never>?
    private var modeNoticeTask: Task<Void, Never>?
    private var modeNoticeID = UUID()
    private var pendingRequest: TranslationRequest?

    init(
        translator: FoundationTranslator,
        modeAvailability: TranslationModeAvailability = TranslationModeAvailability()
    ) {
        self.translator = translator
        self.modeAvailability = modeAvailability
        languageOptions = TranslationLanguageCatalog.available(from: translator.supportedLanguages)
        selectedMode = TranslationMode(
            rawValue: UserDefaults.standard.string(forKey: Self.modePreferenceKey) ?? ""
        ) ?? .lowLatency
    }

    func prepareTranslation(_ text: String) {
        cancelActiveTranslation()
        translationConfiguration = nil
        activeOperation = UUID()
        pendingRequest = nil
        availableModes = []
        isCheckingModes = false
        isTranslating = false
        message = nil
        clearModeNotice()

        let sourceLanguage = TranslationLanguageCatalog.detectSource(in: text)
        guard let targetLanguage = TranslationLanguageCatalog.defaultTarget(
            for: sourceLanguage,
            available: languageOptions
        ) else {
            direction = nil
            message = "No other supported target language is available."
            return
        }

        direction = TranslationDirection(
            activeInputText: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
        isTranslating = true
    }

    func translatePreparedText() async {
        guard let direction else { return }
        let request = TranslationRequest(
            text: direction.activeInputText,
            sourceLanguage: direction.sourceLanguage,
            targetLanguage: direction.targetLanguage
        )
        let operation = activeOperation
        await resolveModesAndTranslate(request, operation: operation)
    }

    func showMessage(_ message: String) {
        activeOperation = UUID()
        cancelActiveTranslation()
        translationConfiguration = nil
        pendingRequest = nil
        isCheckingModes = false
        direction = nil
        isTranslating = false
        self.message = message
        clearModeNotice()
    }

    func selectTarget(_ language: TranslationLanguage) async {
        guard !isTranslating, !isCheckingModes, var direction else { return }
        let request = direction.selectTarget(language)
        self.direction = direction
        await changeDirectionAndTranslate(request)
    }

    func reverseTranslation() async {
        guard !isTranslating, !isCheckingModes, var direction,
              let request = direction.reverse() else {
            return
        }
        self.direction = direction
        await changeDirectionAndTranslate(request)
    }

    func selectMode(_ mode: TranslationMode) {
        guard !isCheckingModes,
              availableModes.contains(mode),
              selectedMode != mode else {
            return
        }

        selectedMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Self.modePreferenceKey)

        guard let direction else { return }
        var updatedDirection = direction
        updatedDirection.clearResult()
        self.direction = updatedDirection

        let request = TranslationRequest(
            text: updatedDirection.activeInputText,
            sourceLanguage: updatedDirection.sourceLanguage,
            targetLanguage: updatedDirection.targetLanguage
        )
        let operation = UUID()
        activeOperation = operation
        beginTranslation(request, operation: operation)
    }

    func translationWork(
        from sourceLanguage: Locale.Language,
        to targetLanguage: Locale.Language,
        mode: TranslationMode
    ) -> TranslationWork? {
        guard let request = pendingRequest,
              selectedMode == mode,
              request.sourceLanguage.locale == sourceLanguage,
              request.targetLanguage.locale == targetLanguage else {
            return nil
        }

        return TranslationWork(text: request.text, operation: activeOperation)
    }

    func completeTranslation(_ text: String, operation: UUID) {
        guard activeOperation == operation else { return }
        setResult(text)
        isTranslating = false
    }

    func failTranslation(_ message: String, operation: UUID) {
        guard activeOperation == operation else { return }
        self.message = message
        isTranslating = false
    }

    private func changeDirectionAndTranslate(_ request: TranslationRequest) async {
        cancelActiveTranslation()
        activeOperation = UUID()
        pendingRequest = nil
        translationConfiguration = nil
        message = nil
        isCheckingModes = true
        isTranslating = true
        clearModeNotice()
        await resolveModesAndTranslate(request, operation: activeOperation)
    }

    private func resolveModesAndTranslate(
        _ request: TranslationRequest,
        operation: UUID
    ) async {
        isCheckingModes = true
        let modes = await modeAvailability.availableModes(
            from: request.sourceLanguage,
            to: request.targetLanguage
        )
        guard activeOperation == operation else { return }
        availableModes = modes

        guard let fallbackMode = availableModes.first else {
            isCheckingModes = false
            isTranslating = false
            message = "No translation mode supports this language pair."
            return
        }

        if !availableModes.contains(selectedMode) {
            let unavailableMode = selectedMode
            selectedMode = fallbackMode
            UserDefaults.standard.set(fallbackMode.rawValue, forKey: Self.modePreferenceKey)
            showModeNotice("\(unavailableMode.title) unavailable → \(fallbackMode.title)")
        }

        isCheckingModes = false
        beginTranslation(request, operation: operation)
    }

    private func beginTranslation(_ request: TranslationRequest, operation: UUID) {
        guard activeOperation == operation else { return }

        activeTranslationTask?.cancel()
        activeTranslationTask = nil
        pendingRequest = request
        message = nil
        isTranslating = true

        if #available(macOS 26.4, *) {
            if let strategy = selectedMode.translationStrategy {
                configureTranslationTask(for: request, strategy: strategy)
                return
            }
        }

        if selectedMode == .foundationModelsStreaming {
            translationConfiguration = nil
            activeTranslationTask = Task { [weak self] in
                await self?.runFoundationModelsTranslation(request, operation: operation)
            }
            return
        }

        configureDefaultTranslationTask(for: request)
    }

    @available(macOS 26.4, *)
    private func configureTranslationTask(
        for request: TranslationRequest,
        strategy: TranslationSession.Strategy
    ) {
        if var configuration = translationConfiguration {
            configuration.source = request.sourceLanguage.locale
            configuration.target = request.targetLanguage.locale
            configuration.preferredStrategy = strategy
            configuration.invalidate()
            translationConfiguration = configuration
        } else {
            translationConfiguration = TranslationSession.Configuration(
                source: request.sourceLanguage.locale,
                target: request.targetLanguage.locale,
                preferredStrategy: strategy
            )
        }
    }

    private func configureDefaultTranslationTask(for request: TranslationRequest) {
        if var configuration = translationConfiguration {
            configuration.source = request.sourceLanguage.locale
            configuration.target = request.targetLanguage.locale
            configuration.invalidate()
            translationConfiguration = configuration
        } else {
            translationConfiguration = TranslationSession.Configuration(
                source: request.sourceLanguage.locale,
                target: request.targetLanguage.locale
            )
        }
    }

    private func runFoundationModelsTranslation(
        _ request: TranslationRequest,
        operation: UUID
    ) async {
        do {
            let result = try await translator.translateStreaming(
                request.text,
                from: request.sourceLanguage,
                to: request.targetLanguage,
                onPartial: { [weak self] partial in
                    guard let self, self.activeOperation == operation else { return }
                    self.setResult(partial)
                }
            )
            guard activeOperation == operation else { return }
            setResult(result)
        } catch {
            guard activeOperation == operation, !Task.isCancelled else { return }
            message = error.localizedDescription
        }

        if activeOperation == operation {
            isTranslating = false
        }
    }

    private func setResult(_ result: String) {
        var direction = self.direction
        direction?.setResult(result)
        self.direction = direction
    }

    private func showModeNotice(_ text: String) {
        modeNoticeTask?.cancel()
        let noticeID = UUID()
        modeNoticeID = noticeID
        modeNotice = text

        modeNoticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self, self.modeNoticeID == noticeID else { return }
            self.modeNotice = nil
        }
    }

    private func clearModeNotice() {
        modeNoticeTask?.cancel()
        modeNoticeTask = nil
        modeNoticeID = UUID()
        modeNotice = nil
    }

    private func cancelActiveTranslation() {
        activeTranslationTask?.cancel()
        activeTranslationTask = nil
    }
}

struct TranslationWork: Sendable {
    let text: String
    let operation: UUID
}
