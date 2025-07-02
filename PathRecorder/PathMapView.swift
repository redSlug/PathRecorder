import SwiftUI
import MapKit

extension Double {
    func isEqual(to other: Double, accuracy: Double) -> Bool {
        return abs(self - other) < accuracy
    }
}

extension MKCoordinateRegion {
    func isSignificantlyDifferent(from other: MKCoordinateRegion, threshold: Double = 0.001) -> Bool {
        return abs(center.latitude - other.center.latitude) > threshold ||
               abs(center.longitude - other.center.longitude) > threshold ||
               abs(span.latitudeDelta - other.span.latitudeDelta) > threshold ||
               abs(span.longitudeDelta - other.span.longitudeDelta) > threshold
    }
}

extension CLLocationCoordinate2D {
    func distance(from other: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return location1.distance(from: location2)
    }
}

/// Represents a segment of a path, used for drawing polylines.
struct PathSegment: Identifiable {
    let id: UUID
    let coordinates: [CLLocationCoordinate2D]
    var polyline: MKPolyline {
        MKPolyline(coordinates: coordinates, count: coordinates.count)
    }
}

/// Displays a map with polylines and GPS point annotations for a recorded path.
struct PathMapView: View {
    let recordedPath: RecordedPath
    @State private var region: MKCoordinateRegion
    @State private var pathSegments: [PathSegment] = []
    @State private var isAutoCentering: Bool = true
    
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
            isAutoCentering: $isAutoCentering,
            locations: recordedPath.locations,
            pathSegments: pathSegments
        )
        .navigationTitle(recordedPath.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

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

// Live PathMapView that updates during recording
struct LivePathMapView: View {
    @ObservedObject var locationManager: LocationManager
    @State private var region: MKCoordinateRegion?
    @State private var isAutoCentering: Bool = true
    @State private var lastCenterTime: Date = Date()
    @State private var lastCenterLocation: CLLocationCoordinate2D?
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        if let currentLocation = locationManager.currentLocation {
            _region = State(initialValue: MKCoordinateRegion(
                center: currentLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        } else {
            _region = State(initialValue: nil)
        }
    }
    
    private func centerOnCurrentLocation() {
        guard isAutoCentering,
              let currentLocation = locationManager.currentLocation,
              Date().timeIntervalSince(lastCenterTime) > 0.5 else { return }
        
        if let lastLocation = lastCenterLocation,
           currentLocation.coordinate.distance(from: lastLocation) < 5 {
            return
        }
        
        let newRegion = MKCoordinateRegion(
            center: currentLocation.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
        )
        
        if region == nil || region!.isSignificantlyDifferent(from: newRegion, threshold: 0.0005) {
            region = newRegion
            lastCenterTime = Date()
            lastCenterLocation = currentLocation.coordinate
        }
    }
    
    var body: some View {
        ZStack {
            if let region = region {
                LiveMapViewControllerRepresentable(
                    region: $region,
                    locations: locationManager.locations,
                    isAutoCentering: isAutoCentering
                )
                .onChange(of: locationManager.locations.count) { _ in
                    centerOnCurrentLocation()
                }
                .onChange(of: locationManager.locations) { _ in
                    centerOnCurrentLocation()
                }
                .onChange(of: locationManager.isPaused) { isPaused in
                    if !isPaused && !isAutoCentering {
                        lastCenterTime = Date().addingTimeInterval(-1)
                        isAutoCentering = true
                        if let currentLocation = locationManager.currentLocation {
                            self.region = MKCoordinateRegion(
                                center: currentLocation.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
                            )
                            lastCenterLocation = currentLocation.coordinate
                            lastCenterTime = Date()
                        }
                    }
                }
                .onAppear {
                    centerOnCurrentLocation()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Force a fresh region update immediately on resume
                    lastCenterTime = Date().addingTimeInterval(-1)
                    centerOnCurrentLocation()
                }
            } else {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Waiting for GPS location...")
                        .padding(.top)
                        .foregroundColor(.secondary)
                }
                .onAppear {
                    centerOnCurrentLocation()
                }
                .onChange(of: locationManager.currentLocation) { _ in
                    centerOnCurrentLocation()
                }
                .onChange(of: locationManager.isPaused) { isPaused in
                    if !isPaused && !isAutoCentering {
                        lastCenterTime = Date().addingTimeInterval(-1)
                        isAutoCentering = true
                        if let currentLocation = locationManager.currentLocation {
                            self.region = MKCoordinateRegion(
                                center: currentLocation.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
                            )
                            lastCenterLocation = currentLocation.coordinate
                            lastCenterTime = Date()
                        }
                    }
                }
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isAutoCentering.toggle()
                        if isAutoCentering, let currentLocation = locationManager.currentLocation {
                            self.region = MKCoordinateRegion(
                                center: currentLocation.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
                            )
                            lastCenterLocation = currentLocation.coordinate
                            lastCenterTime = Date()
                        }
                    }) {
                        Image(systemName: isAutoCentering ? "location.slash.fill" : "location.fill")
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                    .padding()
                    .opacity(region != nil ? 1 : 0.5)
                    .disabled(region == nil)
                }
                Spacer()
            }
        }
    }
}


// MARK: - Efficient LiveMapViewControllerRepresentable

struct LiveMapViewControllerRepresentable: UIViewControllerRepresentable {
    @Binding var region: MKCoordinateRegion?
    var locations: [GPSLocation]
    var isAutoCentering: Bool
    var onUserInteraction: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> LiveMapViewController {
        let vc = LiveMapViewController()
        vc.delegate = context.coordinator
        if let region = region {
            vc.setRegion(region, animated: false)
        }
        vc.setLocations(locations)
        vc.setIsAutoCentering(isAutoCentering)
        return vc
    }

    func updateUIViewController(_ vc: LiveMapViewController, context: Context) {
        vc.setIsAutoCentering(isAutoCentering)
        vc.setLocations(locations)
        if isAutoCentering, let region = region {
            vc.setRegion(region, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, LiveMapViewControllerDelegate {
        var parent: LiveMapViewControllerRepresentable
        init(_ parent: LiveMapViewControllerRepresentable) {
            self.parent = parent
        }
        func regionDidChange(_ region: MKCoordinateRegion, userInitiated: Bool) {
            if userInitiated {
                parent.onUserInteraction?()
            }
            DispatchQueue.main.async {
                self.parent.region = region
            }
        }
    }
}

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

// MARK: - Map Rendering Helpers
struct MapRenderingHelpers {
    static func polylineRenderer(for overlay: MKOverlay) -> MKOverlayRenderer {
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
    static var cachedBlueCircleImage: UIImage? = {
        let size: CGFloat = 8
        let circleView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        circleView.backgroundColor = UIColor.blue
        circleView.layer.cornerRadius = size / 2
        UIGraphicsBeginImageContextWithOptions(circleView.bounds.size, false, 0)
        circleView.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }()
}
