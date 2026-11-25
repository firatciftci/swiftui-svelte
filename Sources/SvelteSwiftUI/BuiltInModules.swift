import Foundation
import Security

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

@MainActor
enum BuiltInModules {
    static var all: Array<NativeModule> {
        [haptics, clipboard, share, links, secureStorage, files]
    }

    struct ImpactOptions: Decodable {
        var style: String?
        var intensity: Double?
    }

    static var haptics: NativeModule {
        NativeModule("haptics")
            .function("impact") { (options: ImpactOptions?) in
                #if os(iOS)
                    let style: UIImpactFeedbackGenerator.FeedbackStyle =
                        switch options?.style {
                        case "light": .light
                        case "heavy": .heavy
                        case "soft": .soft
                        case "rigid": .rigid
                        default: .medium
                        }
                    UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: min(max(options?.intensity ?? 1, 0), 1))
                #elseif os(macOS)
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                #endif
            }
            .function("notification") { (type: String) in
                #if os(iOS)
                    let kind: UINotificationFeedbackGenerator.FeedbackType =
                        switch type {
                        case "warning": .warning
                        case "error": .error
                        default: .success
                        }
                    UINotificationFeedbackGenerator().notificationOccurred(kind)
                #elseif os(macOS)
                    NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
                #endif
            }
            .function("selection") {
                #if os(iOS)
                    UISelectionFeedbackGenerator().selectionChanged()
                #elseif os(macOS)
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                #endif
            }
    }

    static var clipboard: NativeModule {
        NativeModule("clipboard")
            .function("readText") { () -> String? in
                #if os(macOS)
                    NSPasteboard.general.string(forType: .string)
                #else
                    UIPasteboard.general.string
                #endif
            }
            .function("writeText") { (text: String) in
                #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                #else
                    UIPasteboard.general.string = text
                #endif
            }
            .function("hasText") { () -> Bool in
                #if os(macOS)
                    NSPasteboard.general.string(forType: .string) != nil
                #else
                    UIPasteboard.general.hasStrings
                #endif
            }
    }

    struct ShareOptions: Decodable {
        var text: String?
        var url: String?
        var subject: String?
    }

    static var share: NativeModule {
        NativeModule("share")
            .function("share") { (options: ShareOptions) -> Bool in
                let items: Array<Any> = [options.text as Any?, options.url.flatMap(URL.init(string:)) as Any?].compactMap(\.self)
                guard !items.isEmpty else {
                    throw NativeModuleError(code: "invalidArguments", message: "Pass text, a URL, or both to share.")
                }
                return await present(items, subject: options.subject)
            }
    }

    private static func present(_ items: Array<Any>, subject: String?) async -> Bool {
        #if os(iOS) || os(visionOS)
            guard let presenter = topViewController() else { return false }
            return await withCheckedContinuation { continuation in
                let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
                if let subject { controller.setValue(subject, forKey: "subject") }
                controller.completionWithItemsHandler = { _, completed, _, _ in continuation.resume(returning: completed) }
                controller.popoverPresentationController?.sourceView = presenter.view
                controller.popoverPresentationController?.sourceRect = CGRect(
                    x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
                presenter.present(controller, animated: true)
            }
        #elseif os(macOS)
            guard let view = NSApp.keyWindow?.contentView else { return false }
            let picker = NSSharingServicePicker(items: items)
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
            return true
        #else
            return false
        #endif
    }

    #if os(iOS) || os(visionOS)
        private static func topViewController() -> UIViewController? {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
            var controller = window?.rootViewController
            while let presented = controller?.presentedViewController { controller = presented }
            return controller
        }
    #endif

    static var links: NativeModule {
        NativeModule("links")
            .function("open") { (address: String) -> Bool in
                guard let url = URL(string: address), url.scheme != nil else {
                    throw NativeModuleError(code: "invalidArguments", message: "\(address) isn't a URL.")
                }
                #if os(macOS)
                    return NSWorkspace.shared.open(url)
                #else
                    return await UIApplication.shared.open(url)
                #endif
            }
            .function("canOpen") { (address: String) -> Bool in
                guard let url = URL(string: address) else { return false }
                #if os(macOS)
                    return NSWorkspace.shared.urlForApplication(toOpen: url) != nil
                #else
                    return UIApplication.shared.canOpenURL(url)
                #endif
            }
    }

    static var secureStorage: NativeModule {
        NativeModule("secureStorage")
            .function("get") { (key: String) -> String? in try Keychain.read(key) }
            .function("set") { (key: String, value: String) in try Keychain.write(value, for: key) }
            .function("delete") { (key: String) in try Keychain.delete(key) }
    }

    static var files: NativeModule {
        NativeModule("files")
            .function("readText") { (path: String) -> String? in
                let url = try AppFiles.url(for: path)
                guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
                return try String(contentsOf: url, encoding: .utf8)
            }
            .function("writeText") { (path: String, text: String) in
                let url = try AppFiles.url(for: path)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(text.utf8).write(to: url, options: .atomic)
            }
            .function("delete") { (path: String) in
                let url = try AppFiles.url(for: path)
                if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) { try FileManager.default.removeItem(at: url) }
            }
            .function("exists") { (path: String) -> Bool in
                FileManager.default.fileExists(atPath: try AppFiles.url(for: path).path(percentEncoded: false))
            }
            .function("list") { (path: String?) -> Array<String> in
                let url = try AppFiles.url(for: path ?? "")
                let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path(percentEncoded: false))) ?? []
                return names.sorted()
            }
    }
}

enum AppFiles {
    static var root: URL {
        URL.applicationSupportDirectory.appending(path: "swiftui-svelte", directoryHint: .isDirectory)
    }

    static func url(for path: String) throws -> URL {
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        guard !path.hasPrefix("/"), !parts.contains(where: { $0 == ".." || $0 == "." }) else {
            throw NativeModuleError(code: "invalidPath", message: "\(path) must be a relative path inside the app's files.")
        }
        var url = root
        for part in parts { url.append(path: String(part)) }
        return url
    }
}

enum Keychain {
    private static var service: String {
        (Bundle.main.bundleIdentifier ?? "swiftui-svelte") + ".secureStorage"
    }

    private static func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
    }

    static func read(_ key: String) throws -> String? {
        var query = query(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        try check(status)
        return (item as? Data).flatMap { String(bytes: $0, encoding: .utf8) }
    }

    static func write(_ value: String, for key: String) throws {
        let data = Data(value.utf8)
        let status = SecItemUpdate(query(key) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query(key)
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            try check(SecItemAdd(item as CFDictionary, nil))
        } else {
            try check(status)
        }
    }

    static func delete(_ key: String) throws {
        let status = SecItemDelete(query(key) as CFDictionary)
        if status != errSecItemNotFound { try check(status) }
    }

    private static func check(_ status: OSStatus) throws {
        guard status != errSecSuccess else { return }
        let message = (SecCopyErrorMessageString(status, nil) as String?) ?? "Keychain error \(status)"
        throw NativeModuleError(code: "keychain", message: message)
    }
}
