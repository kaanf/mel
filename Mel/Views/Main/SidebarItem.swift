import SwiftUI
import MelSpec

enum SidebarItem: Hashable {
    case discovery(Spec.ID)
    case doc(Spec.ID, DocKind)

    var specID: Spec.ID {
        switch self {
        case .discovery(let id), .doc(let id, _): id
        }
    }

    /// The row that matches where the spec is now.
    static func current(_ spec: Spec) -> SidebarItem {
        switch spec.stage {
        case .discovery: .discovery(spec.id)
        case .drafting(let kind), .review(let kind), .stopped(let kind, _): .doc(spec.id, kind)
        case .analyze, .done: .doc(spec.id, spec.size.files.last!)
        }
    }
}

/// Set by Review while Approve is allowed; drives ⌘↩.
struct ApproveKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var approve: (() -> Void)? {
        get { self[ApproveKey.self] }
        set { self[ApproveKey.self] = newValue }
    }
    /// Set by screens with an inspector; drives ⌥⌘I.
    @Entry var inspectorShown: Binding<Bool>?
}
