import Foundation

nonisolated enum Git {
    static var isAvailable: Bool { fatalError("stub") }
    static func isRepository(_ url: URL) -> Bool { fatalError("stub") }
    static func initRepository(_ url: URL) throws { fatalError("stub") }
    static func commit(paths: [String], message: String, in directory: URL) throws { fatalError("stub") }
}
