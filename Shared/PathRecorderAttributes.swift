import Foundation
import ActivityKit
import SwiftUI

@available(iOS 16.1, *)
public struct PathRecorderAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var latitude: Double
        public var longitude: Double
        public var distance: Double
        public var elapsedTime: TimeInterval
        public var isPaused: Bool
        public var distanceUnit: String // "km" or "mi"
        // public var pace: String

        public init(latitude: Double, longitude: Double, distance: Double, elapsedTime: TimeInterval, isPaused: Bool = false, distanceUnit: String = "km") {
            self.latitude = latitude
            self.longitude = longitude
            self.distance = distance
            self.elapsedTime = elapsedTime
            self.isPaused = isPaused
            self.distanceUnit = distanceUnit
            // self.pace = computePace(distanceMeters: distance, elapsedSeconds: elapsedTime, unit: distanceUnit)
        }
    }
    
    public init() {}
}

// Helper function for formatting time consistently across the app
public func formatTime(_ timeInterval: TimeInterval) -> String {
    let hours = Int(timeInterval) / 3600
    let minutes = Int(timeInterval) / 60 % 60
    let seconds = Int(timeInterval) % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
}

/// Computes pace per mile or km (minutes per unit) given distance in meters and elapsed time in seconds.
/// - Parameters:
///   - distanceMeters: Distance in meters
///   - elapsedSeconds: Elapsed time in seconds
///   - unit: "km" or "mi"
/// - Returns: Pace as a formatted string "mm:ss /unit"
public func computePace(distanceMeters: Double, elapsedSeconds: TimeInterval, unit: String) -> String {
    guard distanceMeters > 0 else { return "--:-- /" + unit }
    let metersPerUnit: Double = (unit == "mi") ? 1609.34 : 1000.0
    let units = distanceMeters / metersPerUnit
    guard units > 0 else { return "--:-- /" + unit }
    let paceSeconds = elapsedSeconds / units
    let paceMinutes = Int(paceSeconds) / 60
    let paceRemainderSeconds = Int(paceSeconds) % 60
    return String(format: "%02d:%02d /%@", paceMinutes, paceRemainderSeconds, unit)
}


