import MapKit

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