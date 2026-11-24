import CoreGraphics
import ScreenCaptureKit
import Vision

enum ScreenTextRecognition {
    static func capture(_ region: ScreenRegion) async throws -> String {
        let image = try await SCScreenshotManager.captureImage(in: region.rect)
        return try await recognize(in: image)
    }

    static func recognize(in image: CGImage) async throws -> String {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        let observations = try await request.perform(on: image)
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
