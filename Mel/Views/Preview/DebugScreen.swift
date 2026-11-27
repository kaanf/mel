#if DEBUG
import SwiftUI
import MelSpec

/// Debug builds only: `-screen <name>` opens one fixture state in the main window (design size
/// 1280 × 800), so it can be captured and compared with its `.dc.html`.
enum DebugScreen: String, CaseIterable {
    case start, noAgent, new, newEmpty, ready, building, buildWorking, buildChanged, buildUnplaced, buildRun, buildReport, buildStopped, buildBlocked, built, settings, specsSettings, board, boardAsking, boardWaiting, boardWriting, boardStopped, boardUnplaced, boardChanged, boardEdited

    static var current: DebugScreen? {
        UserDefaults.standard.string(forKey: "screen").flatMap(DebugScreen.init(rawValue:))
    }

    var state: AppState {
        switch self {
        case .start: PreviewData.appState([], projects: [], foundRepositories: PreviewData.repositories)
        case .noAgent: PreviewData.appState([], agent: .missing, projects: [], foundRepositories: PreviewData.repositories)
        case .new, .newEmpty: PreviewData.appState(PreviewData.others)
        case .ready: PreviewData.appState([PreviewData.done] + PreviewData.others, sessions: [PreviewData.doneSession])
        case .building: PreviewData.appState([PreviewData.buildingSession.spec] + PreviewData.others, sessions: [PreviewData.buildingSession])
        case .buildWorking: PreviewData.appState([PreviewData.buildTellingSession.spec], sessions: [PreviewData.buildTellingSession])
        case .buildChanged: PreviewData.appState([PreviewData.buildChangedSession.spec], sessions: [PreviewData.buildChangedSession])
        case .buildUnplaced: PreviewData.appState([PreviewData.buildUnplacedSession.spec], sessions: [PreviewData.buildUnplacedSession])
        case .buildRun: PreviewData.appState([PreviewData.buildRunSession.spec], sessions: [PreviewData.buildRunSession])
        case .buildReport: PreviewData.appState([PreviewData.buildReportSession.spec], sessions: [PreviewData.buildReportSession])
        case .buildStopped: PreviewData.appState([PreviewData.buildStoppedSession.spec], sessions: [PreviewData.buildStoppedSession])
        case .buildBlocked: PreviewData.appState([PreviewData.buildBlockedSession.spec], sessions: [PreviewData.buildBlockedSession])
        case .built: PreviewData.appState([PreviewData.builtSession.spec] + PreviewData.others, sessions: [PreviewData.builtSession])
        case .settings: PreviewData.appState([])
        case .specsSettings: PreviewData.appState([], contexts: [PreviewData.project.id: PreviewData.context])
        case .board: PreviewData.appState([PreviewData.board] + PreviewData.others, sessions: [PreviewData.boardSession])
        case .boardAsking: PreviewData.appState([PreviewData.boardAsking], sessions: [PreviewData.boardAskingSession])
        case .boardWaiting: PreviewData.appState([PreviewData.boardWaiting], sessions: [PreviewData.boardWaitingSession])
        case .boardWriting: PreviewData.appState([PreviewData.boardWritingSession.spec] + PreviewData.others, sessions: [PreviewData.boardWritingSession])
        case .boardStopped: PreviewData.appState([PreviewData.boardStopped], sessions: [PreviewData.boardStoppedSession])
        case .boardUnplaced: PreviewData.appState([PreviewData.boardUnplaced], sessions: [PreviewData.boardUnplacedSession])
        case .boardChanged: PreviewData.appState([PreviewData.boardChangedSession.spec], sessions: [PreviewData.boardChangedSession])
        case .boardEdited: PreviewData.appState([PreviewData.boardEditedSession.spec], sessions: [PreviewData.boardEditedSession])
        }
    }
}
#endif
