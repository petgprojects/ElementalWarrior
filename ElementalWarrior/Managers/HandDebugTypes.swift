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

enum GestureDebugAttributeStatus: String, Equatable {
    case pass
    case fail
    case neutral
}

struct GestureDebugAttribute: Identifiable, Equatable {
    let id: String
    let name: String
    let value: String
    let status: GestureDebugAttributeStatus

    init(name: String, value: String, status: GestureDebugAttributeStatus = .neutral) {
        self.id = name
        self.name = name
        self.value = value
        self.status = status
    }
}

struct GestureDebugRow: Identifiable, Equatable {
    let id: String
    let title: String
    let status: GestureDebugStatus
    let attributes: [GestureDebugAttribute]

    init(title: String, status: GestureDebugStatus, attributes: [GestureDebugAttribute]) {
        self.id = title
        self.title = title
        self.status = status
        self.attributes = attributes
    }
}
