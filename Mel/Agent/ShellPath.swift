import Foundation

nonisolated enum ShellPath {
    static func loginPATH() async -> String { fatalError("stub") }
    static func find(_ name: String, extraPaths: [String]) async -> URL? { fatalError("stub") }
}
