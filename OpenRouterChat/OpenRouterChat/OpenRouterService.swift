//
//  OpenRouterService.swift
//  OpenRouterChat
//
//  Created by Jason Botterill on 27/12/2025.
//

import Foundation

class OpenRouterService {
    private let baseURL = "https://openrouter.ai/api/v1/chat/completions"
    private let model = "google/gemini-3-pro-preview"
    private var currentTask: Task<Void, Never>?

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "openrouter_api_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "openrouter_api_key") }
    }

    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
    }

    struct ChatRequest: Encodable {
        let model: String
        let messages: [[String: String]]
        let max_tokens: Int
        let stream: Bool
        let reasoning: ReasoningConfig?

        struct ReasoningConfig: Encodable {
            let effort: String
        }
    }

    struct ChatResponse: Decodable {
        let choices: [Choice]

        struct Choice: Decodable {
            let message: ResponseMessage
        }

        struct ResponseMessage: Decodable {
            let content: String?
            let reasoning: String?
        }
    }

    struct StreamDelta: Decodable {
        let choices: [StreamChoice]?

        struct StreamChoice: Decodable {
            let delta: Delta?
            let finish_reason: String?
        }

        struct Delta: Decodable {
            let content: String?
            let reasoning: String?
        }
    }

    func sendMessage(
        messages: [Message],
        reasoningEffort: ReasoningEffort,
        onUpdate: @escaping (String, String?) -> Void
    ) async throws {
        guard !apiKey.isEmpty else {
            throw OpenRouterError.missingAPIKey
        }

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let apiMessages = messages.map { ["role": $0.role.rawValue, "content": $0.content] }

        let reasoning: ChatRequest.ReasoningConfig? = reasoningEffort != .none
            ? ChatRequest.ReasoningConfig(effort: reasoningEffort.rawValue)
            : nil

        let chatRequest = ChatRequest(
            model: model,
            messages: apiMessages,
            max_tokens: 10000,
            stream: true,
            reasoning: reasoning
        )

        request.httpBody = try JSONEncoder().encode(chatRequest)

        let (stream, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            var errorBody = ""
            for try await line in stream.lines {
                errorBody += line
            }
            throw OpenRouterError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        var fullContent = ""
        var fullReasoning: String? = nil

        for try await line in stream.lines {
            try Task.checkCancellation()

            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))

            if jsonString == "[DONE]" { break }

            guard let data = jsonString.data(using: .utf8),
                  let delta = try? JSONDecoder().decode(StreamDelta.self, from: data),
                  let choice = delta.choices?.first else { continue }

            if let content = choice.delta?.content {
                fullContent += content
            }

            if let reasoning = choice.delta?.reasoning {
                if fullReasoning == nil {
                    fullReasoning = reasoning
                } else {
                    fullReasoning! += reasoning
                }
            }

            onUpdate(fullContent, fullReasoning)
        }
    }

    func sendMessageWithTask(
        messages: [Message],
        reasoningEffort: ReasoningEffort,
        onUpdate: @escaping (String, String?) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        currentTask?.cancel()
        currentTask = Task {
            do {
                try await sendMessage(
                    messages: messages,
                    reasoningEffort: reasoningEffort,
                    onUpdate: onUpdate
                )
                await MainActor.run { onComplete() }
            } catch is CancellationError {
                // Silently handle cancellation
            } catch {
                await MainActor.run { onError(error) }
            }
        }
    }
}

enum OpenRouterError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Please enter your OpenRouter API key"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let code, let message):
            return "API Error (\(code)): \(message)"
        }
    }
}
