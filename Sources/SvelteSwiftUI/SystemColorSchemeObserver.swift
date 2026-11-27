import SwiftUI

#if canImport(UIKit)
    import Combine
    import UIKit

    struct SystemColorSchemeObserver: UIViewRepresentable {
        let appearance: ColorScheme?
        let onChange: (ColorScheme) -> Void

        func makeUIView(context _: Context) -> ScreenStyleView {
            ScreenStyleView(onChange: onChange)
        }

        func updateUIView(_ view: ScreenStyleView, context _: Context) {
            view.onChange = onChange
            view.appearance = appearance
        }
    }

    final class ScreenStyleView: UIView {
        var onChange: (ColorScheme) -> Void
        var appearance: ColorScheme? {
            didSet { if appearance != oldValue { applyAppearance() } }
        }
        private weak var styledWindow: UIWindow?
        private var activation: AnyCancellable?
        private var registration: (any UITraitChangeRegistration)?

        init(onChange: @escaping (ColorScheme) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("ScreenStyleView is created in code")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window !== styledWindow {
                styledWindow?.overrideUserInterfaceStyle = .unspecified
                styledWindow = nil
            }
            applyAppearance()
            guard registration == nil, let scene = window?.windowScene else { return }
            report()
            registration = scene.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (_: UIWindowScene, _) in
                self?.report()
            }
            activation = NotificationCenter.default
                .publisher(for: UIApplication.didBecomeActiveNotification)
                .sink { [weak self] _ in self?.report() }
        }

        private func applyAppearance() {
            guard let window else { return }
            styledWindow = window
            window.overrideUserInterfaceStyle =
                switch appearance {
                case .light: .light
                case .dark: .dark
                default: .unspecified
                }
        }

        private func report() {
            guard let scene = window?.windowScene, scene.activationState == .foregroundActive else { return }
            onChange(scene.traitCollection.userInterfaceStyle == .dark ? .dark : .light)
        }
    }
#else
    struct SystemColorSchemeObserver: View {
        let appearance: ColorScheme?
        let onChange: (ColorScheme) -> Void

        var body: some View {
            Color.clear
                .onAppear { onChange(Self.current) }
                .onReceive(
                    DistributedNotificationCenter.default().publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))
                ) { _ in
                    onChange(Self.current)
                }
        }

        private static var current: ColorScheme {
            UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" ? .dark : .light
        }
    }
#endif
