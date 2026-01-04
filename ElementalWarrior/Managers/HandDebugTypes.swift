//
//  HandDebugTypes.swift
//  ElementalWarrior
//
//  Shared debug models for gesture UI.
//

import Foundation

enum GestureDebugStatus: String, Equatable {
    case active
    case inactive
    case unavailable
}

struct GestureDebugRow: Identifiable, Equatable {
    let id: String
    let title: String
    let status: GestureDebugStatus
    let detail: String

    init(title: String, status: GestureDebugStatus, detail: String) {
        self.id = title
        self.title = title
        self.status = status
        self.detail = detail
    }
}
