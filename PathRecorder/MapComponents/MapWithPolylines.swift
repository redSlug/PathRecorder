import SwiftUI
import MapKit
import Foundation

class PhotoAnnotation: NSObject, MKAnnotation {
    let photos: [PathPhoto]
    var coordinate: CLLocationCoordinate2D
    init(photos: [PathPhoto], coordinate: CLLocationCoordinate2D) {
        self.photos = photos
        self.coordinate = coordinate
    }
}

struct MapWithPolylines: UIViewRepresentable {
    var region: MKCoordinateRegion
    let locations: [GPSLocation]
    let pathSegments: [PathSegment]
    let photos: [PathPhoto]
    let onPhotoTapped: (PathPhoto) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        for segment in pathSegments {
            if segment.coordinates.count >= 2 {
                mapView.addOverlay(segment.polyline)
            }
            // Only add GPS point annotation if no photo annotation is nearby (within 10 meters)
            let startCoord = segment.coordinates.first!
            let endCoord = segment.coordinates.last!
            let startLocation = CLLocation(latitude: startCoord.latitude, longitude: startCoord.longitude)
            let endLocation = CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude)
            let photoLocations = photos.map { CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
            let startHasNearbyPhoto = photoLocations.contains { $0.distance(from: startLocation) <= 10.0 }
            let endHasNearbyPhoto = photoLocations.contains { $0.distance(from: endLocation) <= 10.0 }
            if !startHasNearbyPhoto {
                let startAnnotation = MKPointAnnotation()
                startAnnotation.coordinate = startCoord
                mapView.addAnnotation(startAnnotation)
            }
            if !endHasNearbyPhoto {
                let endAnnotation = MKPointAnnotation()
                endAnnotation.coordinate = endCoord
                mapView.addAnnotation(endAnnotation)
            }
        }
        // Group photos within 10 meters
        var clusters: [[PathPhoto]] = []
        for photo in photos {
            let location = CLLocation(latitude: photo.coordinate.latitude, longitude: photo.coordinate.longitude)
            if let idx = clusters.firstIndex(where: { cluster in
                guard let first = cluster.first else { return false }
                let firstLoc = CLLocation(latitude: first.coordinate.latitude, longitude: first.coordinate.longitude)
                return location.distance(from: firstLoc) <= 10.0
            }) {
                clusters[idx].append(photo)
            } else {
                clusters.append([photo])
            }
        }
        // Add one annotation per cluster
        for cluster in clusters {
            guard let first = cluster.first else { continue }
            let coord = first.coordinate
            mapView.addAnnotation(PhotoAnnotation(photos: cluster, coordinate: coord))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, onPhotoTapped: onPhotoTapped)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapWithPolylines
        let onPhotoTapped: (PathPhoto) -> Void
        init(_ parent: MapWithPolylines, onPhotoTapped: @escaping (PathPhoto) -> Void) {
            self.parent = parent
            self.onPhotoTapped = onPhotoTapped
        }
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            return MapRenderingHelpers.polylineRenderer(for: overlay)
        }
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let photoAnnotation = annotation as? PhotoAnnotation {
                let identifier = "PhotoAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                } else {
                    annotationView?.annotation = annotation
                }
                // Use helper for annotation marker image with preview
                let preview = photoAnnotation.photos.first?.image
                annotationView?.image = MapRenderingHelpers.photoAnnotationImage(preview: preview)
                annotationView?.canShowCallout = false
                annotationView?.centerOffset = CGPoint(x: 0, y: 0)
                annotationView?.isUserInteractionEnabled = true
                // Ensure photo annotation is always on top
                annotationView?.layer.zPosition = 1
                return annotationView
            } else {
                let identifier = "GPSPoint"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                } else {
                    annotationView?.annotation = annotation
                }
                annotationView?.image = MapRenderingHelpers.cachedBlueDotImage
                annotationView?.centerOffset = CGPoint(x: 0, y: 0)
                annotationView?.isUserInteractionEnabled = false // Don't block touches
                annotationView?.layer.zPosition = 0
                return annotationView
            }
        }
        func mapView(_ mapView: MKMapView, didSelect annotationView: MKAnnotationView) {
            if let photoAnnotation = annotationView.annotation as? PhotoAnnotation {
                print("Photo annotation tapped at coordinate: \(photoAnnotation.coordinate.latitude), \(photoAnnotation.coordinate.longitude)")
                // Pass all photos in the cluster to the sheet
                if let firstPhoto = photoAnnotation.photos.first {
                    onPhotoTapped(firstPhoto)
                }
            }
        }
    }
}
