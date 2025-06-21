import Foundation
import CoreLocation
import ActivityKit

// Import the PathRecorderAttributes from the Shared folder
import struct Shared.PathRecorderAttributes

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
    @Published var currentLocation: CLLocation?
    @Published var currentActivity: Activity<PathRecorderAttributes>?
    
    private var activityUpdateTimer: Timer?
    
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
        startLiveActivity()
        
        // Start a timer to update the Live Activity every second
        // Using DispatchQueue.main to ensure the timer runs on the main thread
        activityUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let start = self.startTime {
                    self.elapsedTime = Date().timeIntervalSince(start)
                }
                self.updateLiveActivity()
            }
        }
    }
    
    func stopRecording() {
        // Ensure UI updates happen on main thread
        DispatchQueue.main.async {
            self.isRecording = false
            self.locationManager.stopUpdatingLocation()
            if let start = self.startTime {
                self.elapsedTime = Date().timeIntervalSince(start)
            }
            
            // Stop the timer
            self.activityUpdateTimer?.invalidate()
            self.activityUpdateTimer = nil
            
            self.endLiveActivity()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Ensure updates happen on the main thread
        DispatchQueue.main.async {
            self.currentLocation = location
            
            guard self.isRecording else { return }
            
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
                    self.totalDistance += location.distance(from: lastLocation)
                }
            }
            self.updateLiveActivity()
        }
    }
    
    // MARK: - Live Activity Methods
    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { 
            print("Live Activities not available")
            return 
        }
        
        // End any existing activity first to avoid duplicates
        endLiveActivity()
        
        let initialState = PathRecorderAttributes.ContentState(
            latitude: currentLocation?.coordinate.latitude ?? 0,
            longitude: currentLocation?.coordinate.longitude ?? 0,
            distance: totalDistance,
            elapsedTime: 0 // Start with 0 elapsed time
        )
        
        let attributes = PathRecorderAttributes()
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                contentState: initialState,
                pushType: nil
            )
            print("Live Activity started successfully")
        } catch {
            print("Error starting live activity: \(error.localizedDescription)")
        }
    }
    
    private func updateLiveActivity() {
        Task {
            guard let activity = currentActivity else { 
                print("No active Live Activity to update")
                return 
            }
            
            var currentElapsedTime: TimeInterval = 0
            
            // Update elapsed time on main thread and get the value
            await MainActor.run {
                if let start = startTime {
                    self.elapsedTime = Date().timeIntervalSince(start)
                }
                currentElapsedTime = self.elapsedTime
            }
            
            let updatedState = PathRecorderAttributes.ContentState(
                latitude: currentLocation?.coordinate.latitude ?? 0,
                longitude: currentLocation?.coordinate.longitude ?? 0,
                distance: totalDistance,
                elapsedTime: currentElapsedTime
            )
            
            await activity.update(using: updatedState)
            print("Live Activity updated: \(updatedState)")
        }
    }
    
    private func endLiveActivity() {
        Task {
            guard let activity = currentActivity else { return }
            
            // Capture current values on the main thread
            let (lat, long, dist, time) = await MainActor.run {
                return (
                    self.currentLocation?.coordinate.latitude ?? 0,
                    self.currentLocation?.coordinate.longitude ?? 0,
                    self.totalDistance,
                    self.elapsedTime
                )
            }
            
            let finalState = PathRecorderAttributes.ContentState(
                latitude: lat,
                longitude: long,
                distance: dist,
                elapsedTime: time
            )
            
            await activity.end(using: finalState, dismissalPolicy: .immediate)
            
            // Update this property on the main thread
            await MainActor.run {
                self.currentActivity = nil
            }
            
            print("Live Activity ended")
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