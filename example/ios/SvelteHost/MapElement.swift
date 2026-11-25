import MapKit
import SvelteSwiftUI
import SwiftUI

struct MapElement: View {
    let element: NativeElement
    @State private var position = MapCameraPosition.automatic

    private struct Region: Encodable {
        let latitude: Double
        let longitude: Double
    }

    var body: some View {
        let latitude = element.number("latitude") ?? 0
        let longitude = element.number("longitude") ?? 0
        let span = element.number("span") ?? 0.1
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        Map(position: $position) {
            if let title = element.string("marker") {
                Marker(title, coordinate: center)
            }
        }
        .onAppear { position = .region(Self.region(center, span)) }
        .onChange(of: [latitude, longitude, span]) {
            withAnimation { position = .region(Self.region(center, span)) }
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            let center = context.region.center
            element.send("regionchange", Region(latitude: center.latitude, longitude: center.longitude))
        }
    }

    private static func region(_ center: CLLocationCoordinate2D, _ span: Double) -> MKCoordinateRegion {
        MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span))
    }
}
