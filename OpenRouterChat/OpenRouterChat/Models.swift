//
//  Models.swift
//  OpenRouterChat
//
//  Created by Jason Botterill on 27/12/2025.
//

import Foundation
import AppKit

struct ImageAttachment: Identifiable, Equatable {
    let id = UUID()
    let data: Data
    let mimeType: String

    var base64URL: String {
        "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    var nsImage: NSImage? {
        NSImage(data: data)
    }

    static func == (lhs: ImageAttachment, rhs: ImageAttachment) -> Bool {
        lhs.id == rhs.id
    }
}

struct Message: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String
    var reasoning: String?
    var images: [ImageAttachment]

    init(role: Role, content: String, reasoning: String? = nil, images: [ImageAttachment] = []) {
        self.role = role
        self.content = content
        self.reasoning = reasoning
        self.images = images
    }

    enum Role: String {
        case user
        case assistant
    }

    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id && lhs.content == rhs.content && lhs.reasoning == rhs.reasoning
    }
}

enum ReasoningEffort: String, CaseIterable {
    case none = "none"
    case minimal = "minimal"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case xhigh = "xhigh"

    var displayName: String {
        switch self {
        case .none: return "None"
        case .minimal: return "Minimal"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .xhigh: return "Extra High"
        }
    }
}
