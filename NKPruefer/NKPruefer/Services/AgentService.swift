import Foundation

actor AgentService {

    enum AgentError: LocalizedError {
        case invalidResponse
        case apiError(String)
        case decodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Keine gültige Antwort vom Server."
            case .apiError(let msg):
                return "API-Fehler: \(msg)"
            case .decodingFailed(let msg):
                return "Antwort konnte nicht verarbeitet werden: \(msg)"
            }
        }
    }

    // MARK: - Public API

    static func call(
        systemPrompt: String,
        userMessage: String,
        maxTokens: Int = 4096
    ) async throws -> String {
        guard let url = URL(string: NKConfig.claudeBaseURL) else {
            throw AgentError.invalidResponse
        }

        let body = AnthropicRequest(
            model: NKConfig.claudeModel,
            max_tokens: maxTokens,
            system: systemPrompt,
            messages: [.init(role: "user", content: userMessage)]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(NKConfig.claudeAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue(NKConfig.anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 60

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw AgentError.decodingFailed("Request konnte nicht serialisiert werden: \(error.localizedDescription)")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AgentError.apiError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AgentError.invalidResponse
        }

        // Fehler-Pfad: Anthropic gibt JSON mit "error" zurück
        if !(200..<300).contains(http.statusCode) {
            if let errResponse = try? JSONDecoder().decode(AnthropicError.self, from: data) {
                throw AgentError.apiError("\(errResponse.error.type): \(errResponse.error.message)")
            }
            let bodyText = String(data: data, encoding: .utf8) ?? "(kein Body)"
            throw AgentError.apiError("HTTP \(http.statusCode): \(bodyText)")
        }

        // Erfolgs-Pfad
        let decoded: AnthropicResponse
        do {
            decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        } catch {
            throw AgentError.decodingFailed(error.localizedDescription)
        }

        guard let textBlock = decoded.content.first(where: { $0.type == "text" }) else {
            throw AgentError.invalidResponse
        }
        return textBlock.text
    }

    static func callJSON<T: Decodable>(
        systemPrompt: String,
        userMessage: String,
        maxTokens: Int = 4096,
        type: T.Type
    ) async throws -> T {
        let text = try await call(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            maxTokens: maxTokens
        )

        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw AgentError.decodingFailed("Antworttext ist kein gültiges UTF-8")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            df.locale = Locale(identifier: "de_DE")
            df.timeZone = TimeZone(identifier: "UTC")
            if let date = df.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Datum nicht parsbar: \(str)"
            )
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AgentError.decodingFailed(error.localizedDescription)
        }
    }
}

// MARK: - Anthropic Wire-Types

private struct AnthropicRequest: Encodable, Sendable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [Message]

    struct Message: Encodable, Sendable {
        let role: String
        let content: String
    }
}

private struct AnthropicResponse: Decodable, Sendable {
    let content: [ContentBlock]

    struct ContentBlock: Decodable, Sendable {
        let type: String
        let text: String
    }
}

private struct AnthropicError: Decodable, Sendable {
    let type: String
    let error: ErrorDetail

    struct ErrorDetail: Decodable, Sendable {
        let type: String
        let message: String
    }
}
