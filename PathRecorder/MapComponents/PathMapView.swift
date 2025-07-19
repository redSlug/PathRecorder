import SwiftUI
import MapKit

/// Displays a map with polylines and GPS point annotations for a recorded path.
struct PathMapView: View {
    let recordedPath: RecordedPath
    @State private var region: MKCoordinateRegion
    @State private var pathSegments: [PathSegment] = []
    
    @ObservedObject var locationManager: LocationManager
    init(recordedPath: RecordedPath, locationManager: LocationManager) {
        self.recordedPath = recordedPath
        self.locationManager = locationManager
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
        
        _region = State(initialValue: initialRegion)
    }

    var body: some View {
        MapWithPolylines(
            region: region,
            locations: recordedPath.locations,
            pathSegments: pathSegments
        )
        .navigationTitle(recordedPath.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
