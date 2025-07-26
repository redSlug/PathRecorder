import Foundation

enum DistanceUnit: String, CaseIterable, Codable {
    case kilometers = "km"
    case miles = "mi"
    
    var displayName: String {
        switch self {
        case .kilometers:
            return "Kilometers"
        case .miles:
            return "Miles"
        }
    }
    
    var conversionFactor: Double {
        switch self {
        case .kilometers:
            return 1.0
        case .miles:
            return 0.621371 // Convert from meters to miles
        }
    }
    
    var unitLabel: String {
        switch self {
        case .kilometers:
            return "km"
        case .miles:
            return "mi"
        }
    }
}

class Settings: ObservableObject {
    @Published var distanceUnit: DistanceUnit {
        didSet {
            UserDefaults.standard.set(distanceUnit.rawValue, forKey: "distanceUnit")
        }
    }
    
    init() {
        if let savedUnit = UserDefaults.standard.string(forKey: "distanceUnit"),
           let unit = DistanceUnit(rawValue: savedUnit) {
            self.distanceUnit = unit
        } else {
            self.distanceUnit = .kilometers
        }
    }
    
    func convertDistance(_ meters: Double) -> Double {
        return meters / 1000 * distanceUnit.conversionFactor
    }
    
    func formatDistance(_ meters: Double) -> String {
        let convertedDistance = convertDistance(meters)
        return String(format: "%.2f %@", convertedDistance, distanceUnit.unitLabel)
    }
} 