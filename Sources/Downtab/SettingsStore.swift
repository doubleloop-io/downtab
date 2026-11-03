import Foundation
import SwitcherCore
import os

enum ShortcutSlot: CaseIterable {
    case app, window

    var other: ShortcutSlot { self == .app ? .window : .app }
}

/// The App shortcut and the Window shortcut.
struct Shortcuts: Equatable {
    var app: Shortcut
    var window: Shortcut

    static let defaults = Shortcuts(app: .defaultApp, window: .defaultWindow)

    subscript(slot: ShortcutSlot) -> Shortcut {
        get { slot == .app ? app : window }
        set {
            switch slot {
            case .app: app = newValue
            case .window: window = newValue
            }
        }
    }
}

/// Downtab's preferences, kept in `UserDefaults`.
struct SettingsStore {
    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "local.downtab", category: "settings")

    func shortcuts() -> Shortcuts {
        Shortcuts(app: shortcut(for: .app), window: shortcut(for: .window))
    }

    func save(_ shortcuts: Shortcuts) {
        for slot in ShortcutSlot.allCases {
            save(shortcuts[slot], for: slot)
        }
    }

    private func shortcut(for slot: ShortcutSlot) -> Shortcut {
        guard let data = defaults.data(forKey: key(for: slot)) else { return Shortcuts.defaults[slot] }
        do {
            return try JSONDecoder().decode(Shortcut.self, from: data)
        } catch {
            logger.error("stored \(key(for: slot), privacy: .public) unreadable, using the default: \(error)")
            return Shortcuts.defaults[slot]
        }
    }

    private func save(_ shortcut: Shortcut, for slot: ShortcutSlot) {
        do {
            defaults.set(try JSONEncoder().encode(shortcut), forKey: key(for: slot))
        } catch {
            logger.error("cannot store \(key(for: slot), privacy: .public): \(error)")
        }
    }

    private func key(for slot: ShortcutSlot) -> String {
        switch slot {
        case .app: "appShortcut"
        case .window: "windowShortcut"
        }
    }
}
