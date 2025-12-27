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

    var systemPrompt: String {
        get { UserDefaults.standard.string(forKey: "system_prompt") ?? "Don't use lists or em dashes." }
        set { UserDefaults.standard.set(newValue, forKey: "system_prompt") }
    }

    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
    }

    struct ReasoningConfig: Encodable {
        let effort: String
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

        var apiMessages: [[String: Any]] = []

        // Add system prompt first
        if !systemPrompt.isEmpty {
            apiMessages.append(["role": "system", "content": systemPrompt])
        }

        // Build messages with potential image content
        for message in messages {
            if message.images.isEmpty {
                // Simple text message
                apiMessages.append(["role": message.role.rawValue, "content": message.content])
            } else {
                // Multipart message with images
                var contentParts: [[String: Any]] = []

                // Text first (as recommended by docs)
                if !message.content.isEmpty {
                    contentParts.append(["type": "text", "text": message.content])
                }

                // Then images
                for image in message.images {
                    contentParts.append([
                        "type": "image_url",
                        "image_url": ["url": image.base64URL]
                    ])
                }

                apiMessages.append(["role": message.role.rawValue, "content": contentParts])
            }
        }

        let reasoning: ReasoningConfig? = reasoningEffort != .none
            ? ReasoningConfig(effort: reasoningEffort.rawValue)
            : nil

        var requestBody: [String: Any] = [
            "model": model,
            "messages": apiMessages,
            "max_tokens": 10000,
            "stream": true
        ]

        if let reasoning = reasoning {
            requestBody["reasoning"] = ["effort": reasoning.effort]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

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
