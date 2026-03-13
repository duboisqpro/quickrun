import SwiftUI

// AppSettings is NOT an ObservableObject — using @AppStorage inside ObservableObject
// causes "Publishing changes from within view updates" warnings because @AppStorage
// fires objectWillChange synchronously during the render cycle.
// Instead, each view declares its own @AppStorage properties directly.

enum AppTheme: String, CaseIterable, Identifiable {
    case light, dark, system

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light:  return "Light"
        case .dark:   return "Dark"
        case .system: return "System"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
        }
    }
}

// UserDefaults key constants
enum SettingsKey {
    static let theme          = "theme"
    static let launchAtLogin  = "launchAtLogin"
}

// MARK: - Date formatting

extension Date {
    /// Static label that never triggers a SwiftUI timer:
    /// "2:30 PM" if today, "Dec 15 at 2:30 PM" otherwise.
    var shortLabel: String {
        if Calendar.current.isDateInToday(self) {
            return formatted(.dateTime.hour().minute())
        }
        if Calendar.current.isDateInYesterday(self) {
            return "Yesterday at \(formatted(.dateTime.hour().minute()))"
        }
        return formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}
