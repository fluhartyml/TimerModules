import Foundation
import Observation

enum AIError: LocalizedError {
    case missingAPIKey
    case requestFailed(Int)
    case decodingFailed
    case empty

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add an Anthropic API key in Settings to use AI actions."
        case .requestFailed(let status):
            return "Anthropic API returned status \(status)."
        case .decodingFailed:
            return "Couldn't read Anthropic API response."
        case .empty:
            return "Anthropic API returned no usable text."
        }
    }
}

@MainActor
@Observable
final class AIService {
    var isProcessing: Bool = false
    var lastError: String?

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-haiku-4-5-20251001"
    private let maxTokens = 1024

    static let shared = AIService()

    private init() {}

    var hasAPIKey: Bool {
        let key = KeychainStorage.read(.anthropicAPIKey)
        return (key?.isEmpty == false)
    }

    func summarize(_ item: OperatorItem) async -> String? {
        let user = """
        Summarize this record in two sentences. Keep it factual and tight.

        Title: \(item.title)
        Subtitle: \(item.subtitle)
        Notes: \(item.body)
        Tags: \(item.tags.joined(separator: ", "))
        Type: \(item.type.label)
        """
        return await chat(system: "You are a tight, accurate summarizer.", user: user)
    }

    func extractDates(from item: OperatorItem) async -> String? {
        let user = """
        Extract any dates, deadlines, or time references from the following record. Return one date per line in plain language. If none found, say "No dates found."

        Title: \(item.title)
        Subtitle: \(item.subtitle)
        Notes: \(item.body)
        """
        return await chat(system: "You are a date and deadline extractor.", user: user)
    }

    func suggestCategory(for item: OperatorItem) async -> String? {
        let allowed = ItemType.allCases.map { $0.label }.joined(separator: ", ")
        let user = """
        Given this record, recommend ONE category from this list: \(allowed).
        Return only the single category name, nothing else.

        Title: \(item.title)
        Subtitle: \(item.subtitle)
        Notes: \(item.body)
        Tags: \(item.tags.joined(separator: ", "))
        """
        return await chat(system: "You categorize records. Reply with one word from the allowed list.", user: user)
    }

    private func chat(system: String, user: String) async -> String? {
        guard let key = KeychainStorage.read(.anthropicAPIKey), !key.isEmpty else {
            lastError = AIError.missingAPIKey.errorDescription
            return nil
        }

        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let payload: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [
                ["role": "user", "content": user]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                lastError = AIError.decodingFailed.errorDescription
                return nil
            }
            guard (200..<300).contains(http.statusCode) else {
                lastError = AIError.requestFailed(http.statusCode).errorDescription
                return nil
            }
            return parseText(from: data)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    private func parseText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let blocks = json["content"] as? [[String: Any]] else {
            lastError = AIError.decodingFailed.errorDescription
            return nil
        }
        let texts = blocks.compactMap { $0["text"] as? String }
        let joined = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if joined.isEmpty {
            lastError = AIError.empty.errorDescription
            return nil
        }
        return joined
    }
}
