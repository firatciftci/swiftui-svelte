import SwiftUI

#if canImport(UIKit)
    import Combine
    import UIKit

    struct SystemColorSchemeObserver: UIViewRepresentable {
        let onChange: (ColorScheme) -> Void

        func makeUIView(context _: Context) -> ScreenStyleView {
            ScreenStyleView(onChange: onChange)
        }

        func updateUIView(_ view: ScreenStyleView, context _: Context) {
            view.onChange = onChange
        }
    }

    final class ScreenStyleView: UIView {
        var onChange: (ColorScheme) -> Void
        private var activation: AnyCancellable?

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
            guard activation == nil, window != nil else { return }
            report()
            activation = NotificationCenter.default
                .publisher(for: UIApplication.didBecomeActiveNotification)
                .sink { [weak self] _ in self?.report() }
        }

        private func report() {
            guard let screen = window?.screen else { return }
            onChange(screen.traitCollection.userInterfaceStyle == .dark ? .dark : .light)
        }
    }
#else
    struct SystemColorSchemeObserver: View {
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
