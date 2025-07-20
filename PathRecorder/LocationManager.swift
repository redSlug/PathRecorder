import Foundation
import CoreLocation
import ActivityKit

// Import the PathRecorderAttributes from the Shared folder
import struct Shared.PathRecorderAttributes

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var capturedPhotos: [PathPhoto] = []
    func addPhoto(_ photo: PathPhoto) {
        capturedPhotos.append(photo)
        saveRecordingState() // Persist photos immediately after adding
    }
    private let locationManager = CLLocationManager()
    @Published var locations: [GPSLocation] = []
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var totalDistance: Double = 0
    @Published var startTime: Date?
    @Published var elapsedTime: TimeInterval = 0
    @Published var currentLocation: CLLocation?
    @Published var currentActivity: Activity<PathRecorderAttributes>?
    @Published var editingPathId: UUID? = nil
    @Published var editingPathName: String? = nil
    @Published var pathNeedingRename: RecordedPath? = nil // Track path needing rename
    
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
    private var lastTimerUpdate: Date?
    
    // MARK: - Persistence Keys
    private let recordingStateKey = "PathRecorder.RecordingState"

    struct RecordingState: Codable {
        let locations: [GPSLocation]
        let totalDistance: Double
        let elapsedTime: TimeInterval
        let startTime: Date?
        let isPaused: Bool
        let editingPathId: UUID?
        let editingPathName: String?
        let photos: [PathPhoto]
    }

    // MARK: - Persistence Methods
    private func saveRecordingState() {
        let state = RecordingState(
            locations: self.locations,
            totalDistance: self.totalDistance,
            elapsedTime: self.elapsedTime,
            startTime: self.startTime,
            isPaused: self.isPaused,
            editingPathId: self.editingPathId,
            editingPathName: self.editingPathName,
            photos: self.capturedPhotos
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: recordingStateKey)
        }
    }

    private func loadRecordingStateIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: recordingStateKey),
              let state = try? JSONDecoder().decode(RecordingState.self, from: data),
              !state.locations.isEmpty else { return }
        self.locations = state.locations
        self.totalDistance = state.totalDistance
        self.elapsedTime = state.elapsedTime
        self.startTime = state.startTime
        self.isPaused = true // Always restore to paused state
        self.isRecording = true
        self.currentSegmentId = UUID()
        self.editingPathId = state.editingPathId // Restore editingPathId
        self.editingPathName = state.editingPathName // Restore editingPathName
        self.capturedPhotos = state.photos
        print("Restored in-progress recording from disk")
        locationManager.startUpdatingLocation()
        self.startLiveActivity()
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
        // End any orphaned activities and restore the first available one
        Task {
            self.endLiveActivity()
            // Wait briefly for cleanup
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            if let existingActivity = Activity<PathRecorderAttributes>.activities.first {
                await MainActor.run {
                    self.currentActivity = existingActivity
                }
                print("Restored existing Live Activity with ID: \(existingActivity.id)")
            }
        }
        loadRecordingStateIfNeeded()
    }
    
    func requestPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    func startRecording() {
        locations.removeAll()
        totalDistance = 0
        startTime = Date()
        elapsedTime = 0
        lastProcessedLocation = nil
        currentSegmentId = UUID() // Start a new segment
        isRecording = true
        isPaused = false
        locationManager.startUpdatingLocation()
        startLiveActivity()
        
        // Start a timer to update elapsed time and Live Activity every second
        startActivityTimer()
    }
    
    func stopRecording(pathStorage: PathStorage) {        // Save the current path before stopping if pathStorage is provided
        // Ensure UI updates happen on main thread
        DispatchQueue.main.async {
            self.isRecording = false
            self.isPaused = false
            self.locationManager.stopUpdatingLocation()
            
            // Stop and invalidate the timer
            self.stopActivityTimer()
            
            self.endLiveActivity()
            self.saveCurrentPath(to: pathStorage)
            self.editingPathId = nil
            self.editingPathName = nil
            
            UserDefaults.standard.removeObject(forKey: self.recordingStateKey) // Clear saved state
        }
    }
    
    func pauseRecording() {
        guard isRecording && !isPaused else { return }
        
        DispatchQueue.main.async {
            self.isPaused = true
            self.locationManager.stopUpdatingLocation()
            
            // Stop the timer when pausing
            self.stopActivityTimer()
            
            // Update Live Activity to show paused state
            self.updateLiveActivity()
            
            self.saveRecordingState() // Save when paused
        }
    }
    
    func resumeRecording() {
        guard isRecording && isPaused else { return }
        
        DispatchQueue.main.async {
            self.isPaused = false
            
            // Reset only the smoothing data, keep the recorded path
            self.lastProcessedTime = nil
            self.lastProcessedLocation = nil
            self.recentLocations.removeAll()
            
            // Start a new segment when resuming
            self.currentSegmentId = UUID()
            
            self.locationManager.startUpdatingLocation()
            
            // Recreate the timer when resuming
            self.startActivityTimer()
            
            // Update Live Activity to show resumed state
            self.updateLiveActivity()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Ensure updates happen on the main thread
        DispatchQueue.main.async {
            self.currentLocation = location

            if !self.isRecording || self.isPaused { return }
        
            // Filter location by accuracy
            if location.horizontalAccuracy > self.minAccuracy {
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
            
            self.saveRecordingState() // Save after each update
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
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not available or not enabled")
            return
        }
        // End any existing activity first to avoid duplicates
        endLiveActivity()
        // Add a small delay to ensure cleanup is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Assign first available activity if any
            if let existingActivity = Activity<PathRecorderAttributes>.activities.first {
                self.currentActivity = existingActivity
                print("Live Activity already exists, not creating a new one.")
                return
            }
            let initialState = PathRecorderAttributes.ContentState(
                latitude: self.currentLocation?.coordinate.latitude ?? 0,
                longitude: self.currentLocation?.coordinate.longitude ?? 0,
                distance: self.totalDistance,
                elapsedTime: self.elapsedTime,
                isPaused: self.isPaused
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
                return (self.elapsedTime, self.isPaused)
            }
            
            let updatedState = PathRecorderAttributes.ContentState(
                latitude: currentLocation?.coordinate.latitude ?? 0,
                longitude: currentLocation?.coordinate.longitude ?? 0,
                distance: totalDistance,
                elapsedTime: currentElapsedTime,
                isPaused: isPausedState
            )
            
            let content = ActivityContent(state: updatedState, staleDate: nil)
            await activity.update(content)
            print("Live Activity updated successfully")
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
            
            let finalContent = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(finalContent, dismissalPolicy: .immediate)
            print("Live Activity ended successfully")
            
            // Update this property on the main thread
            await MainActor.run {
                self.currentActivity = nil
            }
        }
    }
    
    // MARK: - Timer Management
    private func startActivityTimer() {
        lastTimerUpdate = Date()
        activityUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let now = Date()
                if let lastUpdate = self.lastTimerUpdate {
                    // Add the actual time interval since last update
                    let actualInterval = now.timeIntervalSince(lastUpdate)
                    self.elapsedTime += actualInterval
                }
                self.lastTimerUpdate = now
                self.updateLiveActivity()
            }
        }
    }
    
    private func stopActivityTimer() {
        activityUpdateTimer?.invalidate()
        activityUpdateTimer = nil
        lastTimerUpdate = nil
    }

    func loadPathForEditing(_ path: RecordedPath, pathStorage: PathStorage) {
        guard !isRecording else {
            print("Cannot load path for editing while recording is active")
            return
        }

        // Load the existing data
        self.locations = path.locations
        self.totalDistance = path.totalDistance
        self.elapsedTime = path.totalDuration
        self.startTime = path.startTime
        self.editingPathName = path.name

        // Set up recording state for editing
        self.isRecording = true
        self.isPaused = true // Start in paused state as requested
        self.editingPathId = path.id
        self.capturedPhotos = path.photos
        // Set up for continuing the path
        self.currentSegmentId = UUID() // New segment for continuation
        
        // Start Live Activity immediately with the correct initial values
        self.startLiveActivity()
        
        // Don't start the timer yet since we're starting in paused state
        // The timer will be created when resumeRecording() is called
        
        self.resumeRecording()
        
        print("Loaded existing path for editing - Distance: \(totalDistance)m, Duration: \(elapsedTime)s")
    }
    
    func saveCurrentPath(to pathStorage: PathStorage) {
        guard let startTime = startTime else { return }

        if (editingPathId != nil) {
            // If editing, delete the old path immediately after loading for editing
            pathStorage.deletePath(id: editingPathId!)
        }

        // Create new path
        let recordedPath = RecordedPath(
            startTime: startTime,
            totalDuration: elapsedTime,
            totalDistance: totalDistance,
            locations: locations,
            photos: capturedPhotos,
            name: editingPathName
        )
        pathStorage.savePath(recordedPath)
        capturedPhotos.removeAll()

        // If name is nil, trigger UI to show rename sheet for this path
        if editingPathName == nil {
            DispatchQueue.main.async {
                self.pathNeedingRename = recordedPath
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            print("location authorized always")
            // Enable background location updates when authorized
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.showsBackgroundLocationIndicator = true
        case .authorizedWhenInUse:
            print("location authorized when in use")
            // Background updates not available, disable them
            locationManager.allowsBackgroundLocationUpdates = false
            locationManager.showsBackgroundLocationIndicator = false
        case .denied:
            print("location denied")
            locationManager.allowsBackgroundLocationUpdates = false
            locationManager.showsBackgroundLocationIndicator = false
        case .restricted:
            print("location restricted")
            locationManager.allowsBackgroundLocationUpdates = false
            locationManager.showsBackgroundLocationIndicator = false
        case .notDetermined:
            print("location not determined")
        @unknown default:
            print("location unknown status")
        }
    }
    
    var lastRecordedLocation: CLLocation? {
        locations.last.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
    }
}
