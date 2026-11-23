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
                PickProjectView(
                    onBack: { step = .welcome },
                    onRead: { step = .projectSetup($0) },
                    onIdea: { step = .firstSpec }
                )
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
    /// Setup window chrome: the design's bar, 44 pt with a centered title (A2, A3, A4x) or 52 pt with the
    /// "Setup" step label at the right (A1, A1x). Drawn here instead of a system toolbar, whose height varies.
    func setupChrome(title: String? = nil, stepLabel: String? = nil, barHeight: CGFloat = Theme.Size.titleBar, labelTrailing: CGFloat = Theme.Space.x12) -> some View {
        VStack(spacing: 0) {
            ZStack {
                if let title {
                    Text(title)
                        .textStyle(Theme.Text.bodyBold)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .accessibilityAddTraits(.isHeader)
                }
                if let stepLabel {
                    Text(stepLabel)
                        .textStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, labelTrailing)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: barHeight)
            .contentShape(Rectangle())
            .gesture(WindowDragGesture())
            self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea(.container, edges: .top)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }
}
