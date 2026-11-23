import Foundation
import Observation
import Sparkle

/// Sparkle's standard updater for the app menu and Settings › Updates. The only file that imports Sparkle.
@MainActor @Observable
final class Updater {
    private(set) var canCheckForUpdates = false
    var automaticallyChecksForUpdates: Bool {
        didSet { controller.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates }
    }

    @ObservationIgnored private let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    @ObservationIgnored private var observation: NSKeyValueObservation?

    init() {
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
        // False while a check runs; Sparkle changes it on the main thread.
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            MainActor.assumeIsolated { self?.canCheckForUpdates = updater.canCheckForUpdates }
        }
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}
