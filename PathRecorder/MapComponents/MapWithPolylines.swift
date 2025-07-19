import SwiftUI
import MapKit

struct MapWithPolylines: UIViewRepresentable {
    var region: MKCoordinateRegion
    let locations: [GPSLocation]
    let pathSegments: [PathSegment]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Clear existing overlays and annotations
        mapView.removeOverlays(mapView.overlays)
        // Add updated polylines for each segment
        for segment in pathSegments {
            if segment.coordinates.count >= 2 {
                mapView.addOverlay(segment.polyline)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapWithPolylines
        init(_ parent: MapWithPolylines) {
            self.parent = parent
        }
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            return MapRenderingHelpers.polylineRenderer(for: overlay)
        }
    }
} 