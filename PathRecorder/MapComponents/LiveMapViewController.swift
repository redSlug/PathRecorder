import UIKit
import MapKit

protocol LiveMapViewControllerDelegate: AnyObject {
    func regionDidChange(_ region: MKCoordinateRegion, userInitiated: Bool)
}

class LiveMapViewController: UIViewController, MKMapViewDelegate {
    let mapView = MKMapView()
    weak var delegate: LiveMapViewControllerDelegate?
    private var overlays: [UUID: MKPolyline] = [:]
    private var annotations: [UUID: MKPointAnnotation] = [:]
    var isAutoCentering: Bool = true {
        didSet {
            mapView.isUserInteractionEnabled = !isAutoCentering
        }
    }
    private var isProgrammaticChange = false
    private var isUserInteracting = false
    private var bufferedLocations: [GPSLocation]? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        mapView.frame = view.bounds
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)
        mapView.isUserInteractionEnabled = !isAutoCentering
    }

    func setRegion(_ region: MKCoordinateRegion, animated: Bool) {
        // Only update region if it has changed significantly
        let current = mapView.region
        if current.isSignificantlyDifferent(from: region, threshold: 0.0005) {
            isProgrammaticChange = true
            mapView.setRegion(region, animated: animated)
        }
    }

    func setLocations(_ locations: [GPSLocation]) {
        if isUserInteracting {
            // Buffer locations while user is interacting
            bufferedLocations = locations
            return
        }
        updateMapWithLocations(locations)
    }

    func setIsAutoCentering(_ value: Bool) {
        isAutoCentering = value
        mapView.isUserInteractionEnabled = !value
        // If auto-centering is being enabled, reset user interaction state
        if value {
            isUserInteracting = false
            // Apply any buffered locations immediately
            if let buffered = bufferedLocations {
                updateMapWithLocations(buffered)
                bufferedLocations = nil
            }
        }
    }

    private func updateMapWithLocations(_ locations: [GPSLocation]) {
        // Efficiently update overlays and annotations
        let grouped = Dictionary(grouping: locations, by: { $0.segmentId })
        let segmentIds = Set(grouped.keys)
        for (id, polyline) in overlays where !segmentIds.contains(id) {
            mapView.removeOverlay(polyline)
            overlays.removeValue(forKey: id)
        }
        for (id, locs) in grouped {
            let coords = locs.sorted(by: { $0.timestamp < $1.timestamp }).map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            if let polyline = overlays[id] {
                mapView.removeOverlay(polyline)
            }
            if coords.count >= 2 {
                let polyline = MKPolyline(coordinates: coords, count: coords.count)
                overlays[id] = polyline
                mapView.addOverlay(polyline)
            }
        }
        let locationIds = Set(locations.map { $0.id })
        for (id, annotation) in annotations where !locationIds.contains(id) {
            mapView.removeAnnotation(annotation)
            annotations.removeValue(forKey: id)
        }
        for loc in locations {
            if let annotation = annotations[loc.id] {
                annotation.coordinate = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
            } else {
                let annotation = MKPointAnnotation()
                annotation.coordinate = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
                annotations[loc.id] = annotation
                mapView.addAnnotation(annotation)
            }
        }
    }

    // MARK: - MKMapViewDelegate
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        // Only call onUserInteraction if this is a user gesture
        if !isProgrammaticChange {
            isUserInteracting = true
            delegate?.regionDidChange(mapView.region, userInitiated: true)
        }
    }
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        if isProgrammaticChange {
            isProgrammaticChange = false
            return
        }
        isUserInteracting = false
        // Apply buffered locations if any
        if let buffered = bufferedLocations {
            updateMapWithLocations(buffered)
            bufferedLocations = nil
        }
        delegate?.regionDidChange(mapView.region, userInitiated: false)
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