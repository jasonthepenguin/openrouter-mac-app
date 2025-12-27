//
//  ContentView.swift
//  OpenRouterChat
//
//  Created by Jason Botterill on 27/12/2025.
//

import SwiftUI

struct ContentView: View {
    private let service = OpenRouterService()
    @State private var messages: [Message] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var reasoningEffort: ReasoningEffort = .medium
    @State private var showSettings = false
    @State private var apiKeyInput = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: newChat) {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.borderless)
                .help("New Chat")

                Text("Gemini 3 Pro")
                    .font(.headline)

                Spacer()

                // Reasoning effort picker
                Picker("Reasoning", selection: $reasoningEffort) {
                    ForEach(ReasoningEffort.allCases, id: \.self) { effort in
                        Text(effort.displayName).tag(effort)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)

                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gear")
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            MessageView(message: message)
                                .id(message.id)
                        }

                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Thinking...")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Error message
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            Divider()

            // Input
            HStack {
                TextField("Type a message...", text: $inputText)
                    .textFieldStyle(.plain)
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
        .sheet(isPresented: $showSettings) {
            SettingsView(apiKey: $apiKeyInput, onSave: {
                service.apiKey = apiKeyInput
                showSettings = false
            })
        }
        .onAppear {
            apiKeyInput = service.apiKey
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = Message(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""
        isLoading = true
        errorMessage = nil

        // Add placeholder for assistant response
        let assistantMessage = Message(role: .assistant, content: "", reasoning: nil)
        messages.append(assistantMessage)
        let assistantIndex = messages.count - 1

        service.sendMessageWithTask(
            messages: Array(messages.dropLast()),
            reasoningEffort: reasoningEffort,
            onUpdate: { content, reasoning in
                DispatchQueue.main.async {
                    guard assistantIndex < messages.count else { return }
                    messages[assistantIndex] = Message(
                        role: .assistant,
                        content: content,
                        reasoning: reasoning
                    )
                }
            },
            onComplete: {
                isLoading = false
            },
            onError: { error in
                if assistantIndex < messages.count {
                    messages.removeLast()
                }
                errorMessage = error.localizedDescription
                isLoading = false
            }
        )
    }

    private func newChat() {
        service.cancelCurrentRequest()
        messages = []
        inputText = ""
        isLoading = false
        errorMessage = nil
    }
}

struct MessageView: View {
    let message: Message
    @State private var showReasoning = false

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
            if let reasoning = message.reasoning, !reasoning.isEmpty {
                Button(action: { showReasoning.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: showReasoning ? "brain.fill" : "brain")
                        Text(showReasoning ? "Hide reasoning" : "Show reasoning")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)

                if showReasoning {
                    Text(reasoning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                }
            }

            Text(message.content)
                .padding(10)
                .background(message.role == .user ? Color.blue : Color(NSColor.controlBackgroundColor))
                .foregroundColor(message.role == .user ? .white : .primary)
                .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

struct SettingsView: View {
    @Binding var apiKey: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("OpenRouter API Key")
                    .font(.subheadline)
                SecureField("sk-or-...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                Text("Get your API key at openrouter.ai")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("Save", action: onSave)
                    .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 350)
    }
}

#Preview {
    ContentView()
}
