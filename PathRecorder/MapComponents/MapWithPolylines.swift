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
        mapView.removeAnnotations(mapView.annotations)
        // Add updated polylines and start/end dot annotations for each segment
        for segment in pathSegments {
            if segment.coordinates.count >= 2 {
                mapView.addOverlay(segment.polyline)
            }
            // Add annotation for start point
            let startAnnotation = MKPointAnnotation()
            startAnnotation.coordinate = segment.coordinates.first!
            mapView.addAnnotation(startAnnotation)
            // Add annotation for end point
            let endAnnotation = MKPointAnnotation()
            endAnnotation.coordinate = segment.coordinates.last!
            mapView.addAnnotation(endAnnotation)
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
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "GPSPoint"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }
            annotationView?.image = MapRenderingHelpers.cachedBlueDotImage
            annotationView?.centerOffset = CGPoint(x: 0, y: 0)
            return annotationView
        }
    }
} 
