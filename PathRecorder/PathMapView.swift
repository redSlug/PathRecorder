import SwiftUI
import MapKit

extension Double {
    func isEqual(to other: Double, accuracy: Double) -> Bool {
        return abs(self - other) < accuracy
    }
}

struct PathMapView: View {
    let recordedPath: RecordedPath
    @State private var region: MKCoordinateRegion
    @State private var pathSegments: [PathSegment] = []
    
    struct PathSegment: Identifiable {
        let id: UUID
        let coordinates: [CLLocationCoordinate2D]
        
        var polyline: MKPolyline {
            MKPolyline(coordinates: coordinates, count: coordinates.count)
        }
    }
    
    init(recordedPath: RecordedPath) {
        self.recordedPath = recordedPath
        
        // Group locations by segment first
        let segments = Dictionary(grouping: recordedPath.locations, by: { $0.segmentId })
        let pathSegments = segments.map { segmentId, locations in
            PathSegment(
                id: segmentId,
                coordinates: locations
                    .sorted(by: { $0.timestamp < $1.timestamp })
                    .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            )
        }
        _pathSegments = State(initialValue: pathSegments)
        
        // Calculate the proper region to fit all coordinates
        let allCoordinates = pathSegments.flatMap { $0.coordinates }
        let initialRegion: MKCoordinateRegion
        
        if allCoordinates.isEmpty {
            initialRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        } else {
            let minLat = allCoordinates.map { $0.latitude }.min() ?? 0
            let maxLat = allCoordinates.map { $0.latitude }.max() ?? 0
            let minLon = allCoordinates.map { $0.longitude }.min() ?? 0
            let maxLon = allCoordinates.map { $0.longitude }.max() ?? 0
            
            let centerLat = (minLat + maxLat) / 2
            let centerLon = (minLon + maxLon) / 2
            let latDelta = (maxLat - minLat) * 1.2
            let lonDelta = (maxLon - minLon) * 1.2
            
            initialRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(
                    latitudeDelta: max(latDelta, 0.001),
                    longitudeDelta: max(lonDelta, 0.001)
                )
            )
        }
        
        _region = State(initialValue: initialRegion)
    }

    var body: some View {
        MapWithPolylines(
            region: $region,
            locations: recordedPath.locations,
            pathSegments: pathSegments
        )
        .navigationTitle(recordedPath.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MapWithPolylines: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let locations: [GPSLocation]
    let pathSegments: [PathMapView.PathSegment]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        
        // Add polylines for each segment
        for segment in pathSegments {
            if segment.coordinates.count >= 2 {
                mapView.addOverlay(segment.polyline)
            }
        }
        
        // Add annotations for GPS points
        let annotations = locations.map { location in
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
            return annotation
        }
        mapView.addAnnotations(annotations)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        if !mapView.region.center.latitude.isEqual(to: region.center.latitude, accuracy: 0.0001) ||
           !mapView.region.center.longitude.isEqual(to: region.center.longitude, accuracy: 0.0001) {
            mapView.setRegion(region, animated: true)
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
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.blue
                renderer.lineWidth = 3.0
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "GPSPoint"
            
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }
            
            // Create a blue circle for GPS points
            let circleView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 8))
            circleView.backgroundColor = UIColor.blue
            circleView.layer.cornerRadius = 4
            
            // Convert to UIImage
            UIGraphicsBeginImageContextWithOptions(circleView.bounds.size, false, 0)
            circleView.layer.render(in: UIGraphicsGetCurrentContext()!)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            annotationView?.image = image
            annotationView?.centerOffset = CGPoint(x: 0, y: 0)
            
            return annotationView
        }
    }
}