import SwiftUI
import MapKit

struct PathMapView: View {
    let recordedPath: RecordedPath
    @State private var region: MKCoordinateRegion
    @State private var pathCoordinates: [CLLocationCoordinate2D] = []
    
    init(recordedPath: RecordedPath) {
        self.recordedPath = recordedPath
        
        let coordinates = recordedPath.locations.map { 
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) 
        }
        
        let initialRegion = MKCoordinateRegion(
            center: coordinates.first ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        _region = State(initialValue: initialRegion)
        _pathCoordinates = State(initialValue: coordinates)
    }
    
    var body: some View {
        Map(coordinateRegion: $region, annotationItems: recordedPath.locations) { location in
            MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .overlay(
            Path { path in
                guard !pathCoordinates.isEmpty else { return }
                
                let points = pathCoordinates.map { coordinate in
                    CGPoint(
                        x: (coordinate.longitude - region.center.longitude) / region.span.longitudeDelta * 300 + 150,
                        y: (region.center.latitude - coordinate.latitude) / region.span.latitudeDelta * 300 + 150
                    )
                }
                
                path.move(to: points[0])
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(Color.red, lineWidth: 3)
        )
        .navigationTitle(recordedPath.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fitMapToPath()
        }
    }
    
    private func fitMapToPath() {
        guard !pathCoordinates.isEmpty else { return }
        
        let minLat = pathCoordinates.map { $0.latitude }.min() ?? 0
        let maxLat = pathCoordinates.map { $0.latitude }.max() ?? 0
        let minLon = pathCoordinates.map { $0.longitude }.min() ?? 0
        let maxLon = pathCoordinates.map { $0.longitude }.max() ?? 0
        
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let latDelta = (maxLat - minLat) * 1.2
        let lonDelta = (maxLon - minLon) * 1.2
        
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(
                latitudeDelta: max(latDelta, 0.001),
                longitudeDelta: max(lonDelta, 0.001)
            )
        )
    }
} 