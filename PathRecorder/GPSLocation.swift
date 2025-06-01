import Foundation
import CoreLocation

struct GPSLocation: Identifiable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var locations: [GPSLocation] = []
    @Published var isRecording = false
    @Published var totalDistance: Double = 0
    @Published var startTime: Date?
    @Published var elapsedTime: TimeInterval = 0
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
    }
    
    func requestPermission() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func startRecording() {
        locations.removeAll()
        totalDistance = 0
        startTime = Date()
        isRecording = true
        locationManager.startUpdatingLocation()
    }
    
    func stopRecording() {
        isRecording = false
        locationManager.stopUpdatingLocation()
        if let start = startTime {
            elapsedTime = Date().timeIntervalSince(start)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isRecording else { return }
        
        for location in locations {
            let gpsLocation = GPSLocation(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timestamp: location.timestamp
            )
            self.locations.append(gpsLocation)
            
            if self.locations.count > 1 {
                let lastLocation = CLLocation(
                    latitude: self.locations[self.locations.count - 2].latitude,
                    longitude: self.locations[self.locations.count - 2].longitude
                )
                totalDistance += location.distance(from: lastLocation)
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            print("location authorized always")
        case .authorizedWhenInUse:
            print("location authorized when in use")
        case .denied:
            print("location denied")
        case .restricted:
            print("location restricted")
        case .notDetermined:
            print("location not determined")
        @unknown default:
            print("location unknown status")
        }
    }
} 