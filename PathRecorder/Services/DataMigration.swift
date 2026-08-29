import Foundation
import CoreLocation

class DataMigration {
    static let shared = DataMigration()

    private let userDefaults: UserDefaults
    private let migratedV1Key = "DataMigrationV1Completed"
    private let migratedV2Key = "DataMigrationV2Completed"
    private let migratedV3Key = "DataMigrationV3Completed"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func runMigrations() {
        if !userDefaults.bool(forKey: migratedV1Key) {
            migrateV1()
            userDefaults.set(true, forKey: migratedV1Key)
        }
        if !userDefaults.bool(forKey: migratedV2Key) {
            migrateV2()
            userDefaults.set(true, forKey: migratedV2Key)
        }
        if !userDefaults.bool(forKey: migratedV3Key) {
            migrateV3()
            userDefaults.set(true, forKey: migratedV3Key)
        }
    }

    // MARK: - V1: flat locations → segment-based format

    private func migrateV1() {
        guard let data = userDefaults.data(forKey: "RecordedPaths") else { return }
        do {
            let oldPaths = try JSONDecoder().decode([RecordedPathOld].self, from: data)
            let migrated = oldPaths.map { convertOldPath($0) }
            if let encoded = try? JSONEncoder().encode(migrated) {
                userDefaults.set(encoded, forKey: "RecordedPaths")
            }
        } catch {
            print("V1 migration error: \(error)")
        }
    }

    private func convertOldPath(_ oldPath: RecordedPathOld) -> RecordedPathLenient {
        var allPhotos: [PathPhotoLenient] = []
        var segments: [PathSegmentLenient] = []

        if !oldPath.locations.isEmpty {
            let defaultSegmentId = UUID()
            let grouped = Dictionary(grouping: oldPath.locations) { $0.segmentId ?? defaultSegmentId }

            segments = grouped
                .sorted { ($0.value.first?.timestamp ?? Date()) < ($1.value.first?.timestamp ?? Date()) }
                .map { _, locs in
                    let sorted = locs.sorted { $0.timestamp < $1.timestamp }
                    // Collect GPS-level photos — locationId will be resolved in V2
                    sorted.forEach { loc in
                        loc.photos?.forEach { photo in
                            allPhotos.append(PathPhotoLenient(
                                id: photo.id,
                                timestamp: photo.timestamp,
                                imageFilename: photo.imageFilename,
                                locationId: nil // V2 infers from timestamp
                            ))
                        }
                    }
                    let segmentId = UUID()
                    let locations = sorted.map {
                        GPSLocation(latitude: $0.latitude, longitude: $0.longitude,
                                    timestamp: $0.timestamp, segmentId: segmentId)
                    }
                    return PathSegmentLenient(id: UUID(), locations: locations)
                }
        }

        // Path-level photos (no location context): V2 infers from timestamp
        oldPath.photos?.forEach { photo in
            allPhotos.append(PathPhotoLenient(
                id: photo.id, timestamp: photo.timestamp,
                imageFilename: photo.imageFilename, locationId: nil
            ))
        }

        return RecordedPathLenient(id: oldPath.id, segments: segments,
                                   name: oldPath.name, photos: allPhotos)
    }

    // MARK: - V2: ensure every photo has a valid locationId

    private func migrateV2() {
        guard let data = userDefaults.data(forKey: "RecordedPaths") else { return }
        do {
            var paths = try JSONDecoder().decode([RecordedPathLenient].self, from: data)

            for i in paths.indices {
                let allLocations = paths[i].segments.flatMap { $0.locations }
                paths[i].photos = paths[i].photos.compactMap { photo in
                    let validId = photo.locationId.flatMap { lid in
                        allLocations.contains(where: { $0.id == lid }) ? lid : nil
                    }
                    let resolved = validId ?? allLocations.min(by: {
                        abs($0.timestamp.timeIntervalSince(photo.timestamp)) <
                        abs($1.timestamp.timeIntervalSince(photo.timestamp))
                    })?.id
                    guard let locationId = resolved else { return nil }
                    return PathPhotoLenient(id: photo.id, timestamp: photo.timestamp,
                                           imageFilename: photo.imageFilename, locationId: locationId)
                }
            }

            if let encoded = try? JSONEncoder().encode(paths) {
                userDefaults.set(encoded, forKey: "RecordedPaths")
            }
        } catch {
            print("V2 migration error: \(error)")
        }
    }

    // MARK: - V3: drop stale segment-start anchors from markSegment() called before GPS delivered a fresh location

    private func migrateV3() {
        guard let data = userDefaults.data(forKey: "RecordedPaths") else { return }
        do {
            var paths = try JSONDecoder().decode([RecordedPath].self, from: data)
            // If the gap between a segment's first and second location exceeds this, the first
            // location is a stale cached reading injected at recording start, not a real GPS fix.
            let staleThreshold: TimeInterval = 60

            for i in paths.indices {
                for j in paths[i].segments.indices {
                    let locs = paths[i].segments[j].locations
                    guard locs.count >= 2 else { continue }
                    let gap = locs[1].timestamp.timeIntervalSince(locs[0].timestamp)
                    if gap > staleThreshold {
                        paths[i].segments[j] = PathSegment(
                            id: paths[i].segments[j].id,
                            locations: Array(locs.dropFirst())
                        )
                    }
                }
            }

            if let encoded = try? JSONEncoder().encode(paths) {
                userDefaults.set(encoded, forKey: "RecordedPaths")
            }
        } catch {
            print("V3 migration error: \(error)")
        }
    }
}

// MARK: - Shared lenient types (same JSON shape as RecordedPath / PathPhoto)

private struct RecordedPathLenient: Codable {
    let id: UUID
    var segments: [PathSegmentLenient]
    var name: String
    var photos: [PathPhotoLenient]
}

private struct PathSegmentLenient: Codable {
    let id: UUID
    let locations: [GPSLocation]
}

private struct PathPhotoLenient: Codable {
    let id: UUID
    let timestamp: Date
    let imageFilename: String
    let locationId: UUID?
}

// MARK: - V1 old model shapes

private struct RecordedPathOld: Codable {
    let id: UUID
    let startTime: Date?
    let totalDuration: TimeInterval?
    let totalDistance: Double?
    let locations: [GPSLocationOld]
    let photos: [PathPhotoLenient]?
    let name: String
}

private struct GPSLocationOld: Codable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let segmentId: UUID?
    let photos: [PathPhotoLenient]?
}
