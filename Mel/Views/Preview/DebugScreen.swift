#if DEBUG
import SwiftUI
import MelSpec

/// Debug builds only: `-screen <name>` opens one fixture state in the main window (design size
/// 1280 × 800), so it can be captured and compared with its `.dc.html`.
enum DebugScreen: String, CaseIterable {
    case start, noAgent, new, newEmpty, ready, settings, specsSettings, board, boardAsking, boardWaiting, boardStopped, boardUnplaced, boardChanged, boardEdited

    static var current: DebugScreen? {
        UserDefaults.standard.string(forKey: "screen").flatMap(DebugScreen.init(rawValue:))
    }

    var state: AppState {
        switch self {
        case .start: PreviewData.appState([], projects: [], foundRepositories: PreviewData.repositories)
        case .noAgent: PreviewData.appState([], agent: .missing, projects: [], foundRepositories: PreviewData.repositories)
        case .new, .newEmpty: PreviewData.appState(PreviewData.others)
        case .ready: PreviewData.appState([PreviewData.done] + PreviewData.others, sessions: [PreviewData.doneSession])
        case .settings: PreviewData.appState([])
        case .specsSettings: PreviewData.appState([], contexts: [PreviewData.project.id: PreviewData.context])
        case .board: PreviewData.appState([PreviewData.board] + PreviewData.others, sessions: [PreviewData.boardSession])
        case .boardAsking: PreviewData.appState([PreviewData.boardAsking], sessions: [PreviewData.boardAskingSession])
        case .boardWaiting: PreviewData.appState([PreviewData.boardWaiting], sessions: [PreviewData.boardWaitingSession])
        case .boardStopped: PreviewData.appState([PreviewData.boardStopped], sessions: [PreviewData.boardStoppedSession])
        case .boardUnplaced: PreviewData.appState([PreviewData.boardUnplaced], sessions: [PreviewData.boardUnplacedSession])
        case .boardChanged: PreviewData.appState([PreviewData.boardChangedSession.spec], sessions: [PreviewData.boardChangedSession])
        case .boardEdited: PreviewData.appState([PreviewData.boardEditedSession.spec], sessions: [PreviewData.boardEditedSession])
        }
    }
}
#endif
