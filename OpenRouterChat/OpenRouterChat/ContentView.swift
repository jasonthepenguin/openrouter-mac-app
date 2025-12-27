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
    @State private var systemPromptInput = ""
    @State private var pendingImages: [ImageAttachment] = []
    @FocusState private var isInputFocused: Bool

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

            // Pending images preview
            if !pendingImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(pendingImages) { image in
                            ZStack(alignment: .topTrailing) {
                                if let nsImage = image.nsImage {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                Button(action: { removeImage(image) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .buttonStyle(.borderless)
                                .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(NSColor.controlBackgroundColor))
            }

            // Input
            HStack {
                PastableTextField(text: $inputText, onImagePaste: handleImagePaste, onSubmit: sendMessage)
                    .focused($isInputFocused)

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled((inputText.isEmpty && pendingImages.isEmpty) || isLoading)
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
        .sheet(isPresented: $showSettings) {
            SettingsView(apiKey: $apiKeyInput, systemPrompt: $systemPromptInput, onSave: {
                service.apiKey = apiKeyInput
                service.systemPrompt = systemPromptInput
                showSettings = false
            })
        }
        .onAppear {
            apiKeyInput = service.apiKey
            systemPromptInput = service.systemPrompt
            isInputFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusTextField)) { _ in
            isInputFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .newChat)) { _ in
            newChat()
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !pendingImages.isEmpty else { return }

        let userMessage = Message(role: .user, content: text, images: pendingImages)
        messages.append(userMessage)
        inputText = ""
        pendingImages = []
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
        pendingImages = []
        isLoading = false
        errorMessage = nil
    }

    private func handleImagePaste(_ images: [ImageAttachment]) {
        pendingImages.append(contentsOf: images)
    }

    private func removeImage(_ image: ImageAttachment) {
        pendingImages.removeAll { $0.id == image.id }
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

            // Display images if present
            if !message.images.isEmpty {
                HStack(spacing: 8) {
                    ForEach(message.images) { image in
                        if let nsImage = image.nsImage {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 200, maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            if !message.content.isEmpty {
                Text(message.content)
                    .padding(10)
                    .background(message.role == .user ? Color.blue : Color(NSColor.controlBackgroundColor))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

struct SettingsView: View {
    @Binding var apiKey: String
    @Binding var systemPrompt: String
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

            VStack(alignment: .leading, spacing: 8) {
                Text("System Prompt")
                    .font(.subheadline)
                TextEditor(text: $systemPrompt)
                    .font(.body)
                    .frame(height: 80)
                    .border(Color.secondary.opacity(0.3), width: 1)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("Save", action: onSave)
                    .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

struct PastableTextField: NSViewRepresentable {
    @Binding var text: String
    var onImagePaste: ([ImageAttachment]) -> Void
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let textField = PastableNSTextField()
        textField.delegate = context.coordinator
        textField.onImagePaste = onImagePaste
        textField.placeholderString = "Type a message..."
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PastableTextField

        init(_ parent: PastableTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}

class PastableNSTextField: NSTextField {
    var onImagePaste: (([ImageAttachment]) -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
            if handlePaste() {
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    private func handlePaste() -> Bool {
        let pasteboard = NSPasteboard.general

        // Check for images first
        var images: [ImageAttachment] = []

        // Handle image files
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            for url in urls {
                if let data = try? Data(contentsOf: url),
                   let image = NSImage(data: data) {
                    let mimeType = mimeTypeForURL(url)
                    if let tiffData = image.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {
                        images.append(ImageAttachment(data: pngData, mimeType: mimeType))
                    }
                }
            }
        }

        // Handle direct image data (screenshots, copied images)
        if images.isEmpty {
            for type in [NSPasteboard.PasteboardType.png, NSPasteboard.PasteboardType.tiff] {
                if let data = pasteboard.data(forType: type) {
                    if let image = NSImage(data: data),
                       let tiffData = image.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {
                        images.append(ImageAttachment(data: pngData, mimeType: "image/png"))
                        break
                    }
                }
            }
        }

        if !images.isEmpty {
            onImagePaste?(images)
            return true
        }

        // Fall through to default paste for text
        return false
    }

    private func mimeTypeForURL(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        default: return "image/png"
        }
    }
}

#Preview {
    ContentView()
}
