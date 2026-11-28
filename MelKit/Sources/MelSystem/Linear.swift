import Foundation
import Security

/// Send tasks to Linear (V2-35, OQ #47): its GraphQL API with the user's personal API key, kept in the
/// Keychain. Only when the user sends; Mel makes no other network calls.
public struct LinearClient: Sendable {
    public var key: String
    var endpoint = URL(string: "https://api.linear.app/graphql")!

    public init(key: String) { self.key = key }

    public struct Failure: LocalizedError {
        public var message: String
        public var errorDescription: String? { message }
    }

    public struct Team: Decodable, Sendable {
        public var id: String
        public var name: String
        public var key: String
    }

    public func teams() async throws -> [Team] {
        struct Teams: Decodable { var teams: Nodes; struct Nodes: Decodable { var nodes: [Team] } }
        let data: Teams = try await query("query { teams { nodes { id name key } } }")
        return data.teams.nodes
    }

    /// The team's label with this name, made when it isn't there; its id.
    public func label(_ name: String, team: String) async throws -> String? {
        struct Labels: Decodable { var issueLabels: Nodes; struct Nodes: Decodable { var nodes: [Label] } }
        struct Label: Decodable { var id: String }
        let found: Labels = try await query("query($name: String!, $team: ID!) { issueLabels(filter: { name: { eq: $name }, team: { id: { eq: $team } } }) { nodes { id } } }", ["name": name, "team": team])
        if let id = found.issueLabels.nodes.first?.id { return id }
        struct Created: Decodable { var issueLabelCreate: Result; struct Result: Decodable { var issueLabel: Label? } }
        let created: Created = try await query("mutation($name: String!, $team: String!) { issueLabelCreate(input: { name: $name, teamId: $team }) { issueLabel { id } } }", ["name": name, "team": team])
        return created.issueLabelCreate.issueLabel?.id
    }

    /// One issue; returns its identifier ("YOG-102").
    public func createIssue(title: String, body: String, team: String, label: String?) async throws -> String {
        struct Created: Decodable { var issueCreate: Result; struct Result: Decodable { var issue: Issue? }; struct Issue: Decodable { var identifier: String } }
        var input: [String: Any] = ["title": title, "description": body, "teamId": team]
        if let label { input["labelIds"] = [label] }
        let created: Created = try await query("mutation($input: IssueCreateInput!) { issueCreate(input: $input) { issue { identifier } } }", ["input": input])
        guard let identifier = created.issueCreate.issue?.identifier else { throw Failure(message: "Linear didn’t create the issue.") }
        return identifier
    }

    private func query<T: Decodable>(_ text: String, _ variables: [String: Any] = [:]) async throws -> T {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": text, "variables": variables])
        let (data, response) = try await URLSession.shared.data(for: request)
        let reply = try JSONDecoder().decode(LinearReply<T>.self, from: data)
        if let error = reply.errors?.first { throw Failure(message: error.message) }
        guard let result = reply.data else { throw Failure(message: "Linear answered \((response as? HTTPURLResponse)?.statusCode ?? 0).") }
        return result
    }
}

private struct LinearReply<D: Decodable>: Decodable {
    var data: D?
    var errors: [Message]?
    struct Message: Decodable { var message: String }
}

/// The Linear key in the login Keychain (a generic password Mel owns).
public enum LinearKey {
    static let service = "com.kaanf.mel.linear"

    public static func read() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecReturnData as String: true]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    public static func save(_ key: String) throws {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = Data(key.utf8)
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw LinearClient.Failure(message: "The Keychain refused the key (\(status)).") }
    }

    public static func delete() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service] as CFDictionary)
    }
}
