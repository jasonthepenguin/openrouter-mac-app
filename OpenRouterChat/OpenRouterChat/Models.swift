//
//  Models.swift
//  OpenRouterChat
//
//  Created by Jason Botterill on 27/12/2025.
//

import Foundation

struct Message: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String
    var reasoning: String?

    enum Role: String {
        case user
        case assistant
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
