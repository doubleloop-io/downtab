import Foundation
import SwitcherCore
import os

/// Downtab's preferences, kept in `UserDefaults`.
struct SettingsStore {
    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "io.doubleloop.downtab", category: "settings")

    func shortcuts() -> Shortcuts {
        Shortcuts(app: shortcut(for: .app), window: shortcut(for: .window))
    }

    func save(_ shortcuts: Shortcuts) {
        for slot in ShortcutSlot.allCases {
            save(shortcuts[slot], for: slot)
        }
    }

    func launchAtLogin() -> Bool {
        defaults.object(forKey: Self.launchAtLoginKey) as? Bool ?? true
    }

    func save(launchAtLogin: Bool) {
        defaults.set(launchAtLogin, forKey: Self.launchAtLoginKey)
    }

    private static let launchAtLoginKey = "launchAtLogin"

    private func shortcut(for slot: ShortcutSlot) -> Shortcut {
        guard let data = defaults.data(forKey: slot.storageKey) else { return Shortcuts.defaults[slot] }
        do {
            return try JSONDecoder().decode(Shortcut.self, from: data)
        } catch {
            logger.error("stored \(slot.storageKey, privacy: .public) unreadable, using the default: \(error)")
            return Shortcuts.defaults[slot]
        }
    }

    private func save(_ shortcut: Shortcut, for slot: ShortcutSlot) {
        do {
            defaults.set(try JSONEncoder().encode(shortcut), forKey: slot.storageKey)
        } catch {
            logger.error("cannot store \(slot.storageKey, privacy: .public): \(error)")
        }
    }
}

extension ShortcutSlot {
    fileprivate var storageKey: String {
        switch self {
        case .app: "appShortcut"
        case .window: "windowShortcut"
        }
    }
}
