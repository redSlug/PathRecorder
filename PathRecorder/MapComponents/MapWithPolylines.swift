import SwiftUI
import MapKit

struct MapWithPolylines: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var isAutoCentering: Bool
    let locations: [GPSLocation]
    let pathSegments: [PathSegment]
    var onUserInteraction: (() -> Void)? = nil
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        if isAutoCentering {
            let newRegion = region
            if mapView.region.isSignificantlyDifferent(from: newRegion, threshold: 0.001) {
                context.coordinator.isProgrammaticChange = true
                mapView.setRegion(newRegion, animated: true)
            }
        }
        // Clear existing overlays and annotations
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        // Add updated polylines for each segment
        for segment in pathSegments {
            if segment.coordinates.count >= 2 {
                mapView.addOverlay(segment.polyline)
            }
        }
        // Add updated annotations for GPS points
        let annotations = locations.map { location in
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
            return annotation
        }
        mapView.addAnnotations(annotations)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapWithPolylines
        var isProgrammaticChange = false
        init(_ parent: MapWithPolylines) {
            self.parent = parent
        }
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            if !isProgrammaticChange {
                parent.onUserInteraction?()
            }
        }
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            if isProgrammaticChange {
                isProgrammaticChange = false
                return
            }
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
        }
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            return MapRenderingHelpers.polylineRenderer(for: overlay)
        }
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "GPSPoint"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }
            annotationView?.image = MapRenderingHelpers.cachedBlueCircleImage
            return annotationView
        }
    }
} 