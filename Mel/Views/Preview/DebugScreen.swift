#if DEBUG
import SwiftUI
import MelSpec

/// Debug builds only: `-screen <name>` opens one fixture state in the main window (design size
/// 1280 × 800), so it can be captured and compared with its `.dc.html`.
enum DebugScreen: String, CaseIterable {
    case welcome, noAgent, pickProject, projectSetup, firstSpec, newSpec, newSpecNoContext, newSpecQuickFix, newSpecProduct, newSpecEmpty, intake, drafting, review, experience, edited, analyze, ready, stopped, home

    static var current: DebugScreen? {
        UserDefaults.standard.string(forKey: "screen").flatMap(DebugScreen.init(rawValue:))
    }

    /// Lane A screens start the setup flow at this step.
    var setupStep: SetupFlow.Step? {
        switch self {
        case .pickProject: .pickProject
        case .projectSetup: .projectSetup(PreviewData.project)
        case .firstSpec: .firstSpec
        default: nil
        }
    }

    /// B1 screens open New Spec with this draft.
    var newSpecDraft: NewSpecView.Draft? {
        switch self {
        case .newSpec: PreviewData.featureDraft
        case .newSpecNoContext: PreviewData.featureDraftNoContext
        case .newSpecQuickFix: PreviewData.quickFixDraft
        case .newSpecProduct: NewSpecView.Draft(size: .product)
        case .newSpecEmpty: NewSpecView.Draft()
        default: nil
        }
    }

    var state: AppState {
        switch self {
        case .welcome: PreviewData.appState([], projects: [])
        case .noAgent: PreviewData.appState([], agent: .missing, projects: [])
        case .pickProject: PreviewData.appState([], projects: [], foundRepositories: PreviewData.repositories)
        case .firstSpec: PreviewData.appState([], projects: [])
        case .projectSetup: PreviewData.appState([], projects: [], projectSetup: PreviewData.projectSetup)
        case .newSpec, .newSpecNoContext, .newSpecQuickFix, .newSpecProduct, .newSpecEmpty: PreviewData.newSpecState
        case .intake: PreviewData.appState([PreviewData.intake])
        case .drafting: PreviewData.appState([PreviewData.drafting], sessions: [PreviewData.draftingSession])
        case .review: PreviewData.appState([PreviewData.reviewRoundTwo], sessions: [PreviewData.reviewSession])
        case .experience: PreviewData.appState([PreviewData.reviewExperience], sessions: [PreviewData.experienceSession])
        case .edited: PreviewData.appState([PreviewData.edited])
        case .analyze: PreviewData.appState([PreviewData.analyzeIssues])
        case .ready: PreviewData.appState([PreviewData.done], sessions: [PreviewData.doneSession])
        case .stopped: PreviewData.appState([PreviewData.usageLimit])
        case .home: PreviewData.appState([])
        }
    }
}
#endif
