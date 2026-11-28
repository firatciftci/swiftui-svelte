import Foundation

extension SvelteView {
    public enum URLHandling: Sendable {
        case automatic
        case preferred
        case never
    }

    public func handlesURLs(_ handling: URLHandling) -> SvelteView {
        var view = self
        view.urlHandling = handling
        return view
    }
}

final class URLRouter {
    static let shared = URLRouter()

    private struct Offer {
        let runtime: SvelteRuntime
        let appearance: Int
        let isPreferred: Bool
    }

    private var appearances = 0
    private var offers: Array<(url: URL, candidates: Array<Offer>)> = []

    func nextAppearance() -> Int {
        appearances += 1
        return appearances
    }

    func offer(_ url: URL, to runtime: SvelteRuntime, appearance: Int, handling: SvelteView.URLHandling) {
        guard handling != .never else { return }
        if offers.isEmpty { DispatchQueue.main.async { [weak self] in self?.route() } }
        let offer = Offer(runtime: runtime, appearance: appearance, isPreferred: handling == .preferred)
        if let index = offers.firstIndex(where: { $0.url == url }) {
            offers[index].candidates.append(offer)
        } else {
            offers.append((url, [offer]))
        }
    }

    func route() {
        let routed = offers
        offers = []
        for (url, candidates) in routed {
            let owner = candidates.min { ($0.isPreferred ? 0 : 1, $0.appearance) < ($1.isPreferred ? 0 : 1, $1.appearance) }
            owner?.runtime.open(url)
        }
    }
}
