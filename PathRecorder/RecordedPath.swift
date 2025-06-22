import Foundation
import CoreLocation

struct RecordedPath: Identifiable, Codable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let totalDistance: Double
    let locations: [GPSLocation]
    let name: String
    
    init(startTime: Date, endTime: Date, totalDistance: Double, locations: [GPSLocation]) {
        self.startTime = startTime
        self.endTime = endTime
        self.totalDistance = totalDistance
        self.locations = locations
        self.name = "Path \(DateFormatter.localizedString(from: startTime, dateStyle: .short, timeStyle: .short))"
    }
}

struct GPSLocation: Identifiable, Codable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}

class PathStorage: ObservableObject {
    @Published var recordedPaths: [RecordedPath] = []
    private let userDefaults = UserDefaults.standard
    private let key = "RecordedPaths"
    
    init() {
        loadPaths()
    }
    
    func savePath(_ path: RecordedPath) {
        recordedPaths.append(path)
        saveToUserDefaults()
    }
    
    func deletePath(_ path: RecordedPath) {
        recordedPaths.removeAll { $0.id == path.id }
        saveToUserDefaults()
    }
    
    private func saveToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(recordedPaths) {
            userDefaults.set(encoded, forKey: key)
        }
    }
    
    private func loadPaths() {
        if let data = userDefaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([RecordedPath].self, from: data) {
            recordedPaths = decoded
        }
    }
} 