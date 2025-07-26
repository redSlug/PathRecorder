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

        public init(latitude: Double, longitude: Double, distance: Double, elapsedTime: TimeInterval, isPaused: Bool = false, distanceUnit: String = "km") {
            self.latitude = latitude
            self.longitude = longitude
            self.distance = distance
            self.elapsedTime = elapsedTime
            self.isPaused = isPaused
            self.distanceUnit = distanceUnit
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

