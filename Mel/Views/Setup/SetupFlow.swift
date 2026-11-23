import SwiftUI
import MelSpec

/// Lane A in the main window (design/v2): A1 Welcome or A1x, A2 Pick a project, A3 Project context, A4x first spec.
struct SetupFlow: View {
    enum Step: Hashable {
        case welcome, pickProject, projectSetup(Project), firstSpec
    }

    @Environment(AppState.self) private var state
    @AppStorage("didShowWelcome") private var didShowWelcome = false
    @State var step: Step
    /// Lane A is done: show the library, with B1 New Spec open when `newSpec`.
    let onFinish: (_ newSpec: Bool) -> Void

    var body: some View {
        Group {
            switch step {
            case .welcome:
                if state.agent == .missing {
                    NoAgentView(onLookAround: leaveWelcome)
                } else {
                    WelcomeView(onContinue: leaveWelcome)
                }
            case .pickProject:
                ContentUnavailableView("Pick a Project", systemImage: "folder")   // A2, next in Wave 6
                    .setupChrome(title: "Set Up Project")
            case .projectSetup:
                ContentUnavailableView("Project Context", systemImage: "house")   // A3, next in Wave 6
                    .setupChrome(title: "Set Up Project")
            case .firstSpec:
                ContentUnavailableView("New Spec", systemImage: "doc")            // A4x, with B1
                    .setupChrome(title: "New Spec")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
    }

    private func leaveWelcome() {
        didShowWelcome = true
        step = .pickProject
    }
}

extension View {
    /// Setup window chrome: centered title (A2, A3, A4x) or the "Setup" step label at the right (A1, A1x).
    func setupChrome(title: String? = nil, stepLabel: String? = nil) -> some View {
        toolbar {
            if let title {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .textStyle(Theme.Text.bodyBold)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            if let stepLabel {
                ToolbarSpacer(.flexible)
                ToolbarItem {
                    Text(stepLabel)
                        .textStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }
}
