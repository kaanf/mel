import Foundation

public enum Git {
    public static var isAvailable: Bool { fatalError("stub") }
    public static func isRepository(_ url: URL) -> Bool { fatalError("stub") }
    public static func initRepository(_ url: URL) throws { fatalError("stub") }
    public static func commit(paths: [String], message: String, in directory: URL) throws { fatalError("stub") }
}
