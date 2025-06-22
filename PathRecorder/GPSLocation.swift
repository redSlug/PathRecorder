import Foundation
import CoreLocation
import ActivityKit

// Import the PathRecorderAttributes from the Shared folder
import struct Shared.PathRecorderAttributes

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var locations: [GPSLocation] = []
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var totalDistance: Double = 0
    @Published var startTime: Date?
    @Published var elapsedTime: TimeInterval = 0
    @Published var pausedTime: TimeInterval = 0
    @Published var pauseStartTime: Date?
    @Published var currentLocation: CLLocation?
    @Published var currentActivity: Activity<PathRecorderAttributes>?
    
    // Properties for improved distance calculation
    private var lastProcessedTime: Date?
    private var lastProcessedLocation: CLLocation?
    private var recentLocations: [CLLocation] = [] // For moving average calculation
    private let minAccuracy: CLLocationAccuracy = 20.0 // Accuracy threshold in meters
    private let minDistance: Double = 2.0 // Minimum distance in meters
    private let minTimeInterval: TimeInterval = 2.0 // Minimum seconds between location updates
    private let maxLocationsForAverage: Int = 3 // Number of locations to use for moving average
    
    // Track recording segments for proper line drawing
    private var currentSegmentId: UUID = UUID()
    
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
        pausedTime = 0
        pauseStartTime = nil
        lastProcessedLocation = nil
        currentSegmentId = UUID() // Start a new segment
        isRecording = true
        isPaused = false
        locationManager.startUpdatingLocation()
        startLiveActivity()
        
        // Start a timer to update the Live Activity every second
        // Using DispatchQueue.main to ensure the timer runs on the main thread
        activityUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let start = self.startTime, !self.isPaused {
                    self.elapsedTime = Date().timeIntervalSince(start) - self.pausedTime
                }
                self.updateLiveActivity()
            }
        }
    }
    
    func stopRecording() {
        // Ensure UI updates happen on main thread
        DispatchQueue.main.async {
            self.isRecording = false
            self.isPaused = false
            self.locationManager.stopUpdatingLocation()
            if let start = self.startTime {
                self.elapsedTime = Date().timeIntervalSince(start) - self.pausedTime
            }
            
            // Stop the timer
            self.activityUpdateTimer?.invalidate()
            self.activityUpdateTimer = nil
            
            self.endLiveActivity()
        }
    }
    
    func pauseRecording() {
        guard isRecording && !isPaused else { return }
        
        DispatchQueue.main.async {
            self.isPaused = true
            self.pauseStartTime = Date()
            self.locationManager.stopUpdatingLocation()
            
            // Update Live Activity to show paused state
            self.updateLiveActivity()
        }
    }
    
    func resumeRecording() {
        guard isRecording && isPaused else { return }
        
        DispatchQueue.main.async {
            // Calculate time spent in paused state and add to total pausedTime
            if let pauseStart = self.pauseStartTime {
                self.pausedTime += Date().timeIntervalSince(pauseStart)
                self.pauseStartTime = nil
            }
            
            self.isPaused = false
            
            // Reset only the smoothing data, keep the recorded path
            self.lastProcessedTime = nil
            self.lastProcessedLocation = nil
            self.recentLocations.removeAll()
            
            // Start a new segment when resuming
            self.currentSegmentId = UUID()
            
            self.locationManager.startUpdatingLocation()
            
            // Update Live Activity to show resumed state
            self.updateLiveActivity()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Ensure updates happen on the main thread
        DispatchQueue.main.async {
            self.currentLocation = location
            
            // Don't process location updates if recording is not active or is paused
            guard self.isRecording && !self.isPaused else { return }
            
            // Filter location by accuracy
            guard location.horizontalAccuracy <= self.minAccuracy else {
                print("Skipping location due to poor accuracy: \(location.horizontalAccuracy)m")
                return
            }
            
            // Time-based filtering
            if let lastTime = self.lastProcessedTime,
               location.timestamp.timeIntervalSince(lastTime) < self.minTimeInterval {
                print("Skipping location - too soon after last update")
                return
            }
            
            // Update the last processed time
            self.lastProcessedTime = location.timestamp
            
            // Add to recent locations for moving average (limited to maxLocationsForAverage)
            self.recentLocations.append(location)
            if self.recentLocations.count > self.maxLocationsForAverage {
                self.recentLocations.removeFirst()
            }
            
            let avgLocation = self.calculateAverageLocation(self.recentLocations)
        
            // Create the GPS location from the averaged coordinates
            let gpsLocation = GPSLocation(
                latitude: avgLocation.coordinate.latitude,
                longitude: avgLocation.coordinate.longitude,
                timestamp: location.timestamp,
                segmentId: self.currentSegmentId
            )
            self.locations.append(gpsLocation)

            // Compare with previous location (if exists)
            if self.lastProcessedLocation != nil {
                // Calculate distance to previous location
                let distance = avgLocation.distance(from: self.lastProcessedLocation!)
                
                // Only record if we've moved at least minDistance
                if distance >= self.minDistance {
                    self.totalDistance += distance
                    print("Distance added: \(distance)m, Total: \(self.totalDistance)m")
                } else {
                    print("Skipping - distance too small: \(distance)m")
                }
            }
            // This is the first location, just add it
            self.lastProcessedLocation = avgLocation
            print("Location recorded")
            
            
            self.updateLiveActivity()
        }
    }
    
    // Helper method to calculate the average location from a set of locations
    private func calculateAverageLocation(_ locations: [CLLocation]) -> CLLocation {
        guard !locations.isEmpty else { return CLLocation() }
        
        // Calculate average latitude and longitude
        var totalLat: Double = 0
        var totalLong: Double = 0
        
        for location in locations {
            totalLat += location.coordinate.latitude
            totalLong += location.coordinate.longitude
        }
        
        let avgLat = totalLat / Double(locations.count)
        let avgLong = totalLong / Double(locations.count)
        
        return CLLocation(latitude: avgLat, longitude: avgLong)
    }
    
    // MARK: - Live Activity Methods
    private func startLiveActivity() {
        // Check if Live Activities are available
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { 
            print("Live Activities not available or not enabled")
            return 
        }
        
        // End any existing activity first to avoid duplicates
        endLiveActivity()
        
        // Add a small delay to ensure cleanup is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let initialState = PathRecorderAttributes.ContentState(
                latitude: self.currentLocation?.coordinate.latitude ?? 0,
                longitude: self.currentLocation?.coordinate.longitude ?? 0,
                distance: self.totalDistance,
                elapsedTime: 0, // Start with 0 elapsed time
                isPaused: false
            )
            
            let attributes = PathRecorderAttributes()
            
            do {
                let content = ActivityContent(state: initialState, staleDate: nil)
                self.currentActivity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                print("Live Activity started successfully with ID: \(self.currentActivity?.id ?? "unknown")")
            } catch {
                print("Error starting live activity: \(error.localizedDescription)")
                // Log more details about the error
                if let error = error as NSError? {
                    print("Error domain: \(error.domain), code: \(error.code)")
                    print("Error userInfo: \(error.userInfo)")
                }
            }
        }
    }
    
    private func updateLiveActivity() {
        Task {
            guard let activity = currentActivity else { 
                print("No active Live Activity to update")
                return 
            }
            
            // Capture values from main thread
            let (currentElapsedTime, isPausedState) = await MainActor.run {
                if let start = startTime {
                    if !isPaused {
                        self.elapsedTime = Date().timeIntervalSince(start) - self.pausedTime
                    }
                }
                return (self.elapsedTime, self.isPaused)
            }
            
            let updatedState = PathRecorderAttributes.ContentState(
                latitude: currentLocation?.coordinate.latitude ?? 0,
                longitude: currentLocation?.coordinate.longitude ?? 0,
                distance: totalDistance,
                elapsedTime: currentElapsedTime,
                isPaused: isPausedState
            )
            
            do {
                let content = ActivityContent(state: updatedState, staleDate: nil)
                await activity.update(content)
                print("Live Activity updated successfully")
            } catch {
                print("Error updating Live Activity: \(error.localizedDescription)")
                if let error = error as NSError? {
                    print("Update error domain: \(error.domain), code: \(error.code)")
                }
            }
        }
    }
    
    private func endLiveActivity() {
        Task {
            guard let activity = currentActivity else { 
                print("No active Live Activity to end")
                return 
            }
            
            print("Ending Live Activity with ID: \(activity.id)")
            
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
                elapsedTime: time,
                isPaused: false
            )
            
            do {
                let finalContent = ActivityContent(state: finalState, staleDate: nil)
                await activity.end(finalContent, dismissalPolicy: .immediate)
                print("Live Activity ended successfully")
            } catch {
                print("Error ending Live Activity: \(error.localizedDescription)")
                if let error = error as NSError? {
                    print("End error domain: \(error.domain), code: \(error.code)")
                }
            }
            
            // Update this property on the main thread
            await MainActor.run {
                self.currentActivity = nil
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