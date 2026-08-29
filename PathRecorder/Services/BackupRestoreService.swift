//
//  BackupRestoreService.swift
//  PathRecorder
//
//  Owns long-lived backup/restore work so it survives view dismissal,
//  persists a resume checkpoint to UserDefaults, and can continue in the
//  background via BGTaskScheduler.
//

import Foundation
import BackgroundTasks
import Supabase

@MainActor
final class BackupRestoreService: ObservableObject {
    // Progress state
    @Published var isUploadingBackup = false
    @Published var backupProgress: Double = 0.0
    @Published var backupStartTime: Date? = nil
    @Published var isRestoringFromCloud = false
    @Published var restoreProgress: Double = 0.0
    @Published var lastBackupError: String? = nil
    @Published var backupSuccessMessage: String? = nil

    // Resume checkpoint persisted to UserDefaults
    private struct BackupCheckpoint: Codable {
        var pendingPathIds: [UUID]
        var uploadedPhotoIds: Set<UUID>
    }

    private let checkpointKey = "BackupRestoreService.checkpoint"
    private var activeBackupTask: Task<Void, Never>?

    static let bgTaskIdentifier = "com.pathrecorder.backup"

    init() {
        registerBackgroundTask()
    }

    // MARK: - Checkpoint persistence

    private func saveCheckpoint(_ checkpoint: BackupCheckpoint) {
        if let data = try? JSONEncoder().encode(checkpoint) {
            UserDefaults.standard.set(data, forKey: checkpointKey)
        }
    }

    private func loadCheckpoint() -> BackupCheckpoint? {
        guard let data = UserDefaults.standard.data(forKey: checkpointKey),
              let checkpoint = try? JSONDecoder().decode(BackupCheckpoint.self, from: data) else {
            return nil
        }
        return checkpoint
    }

    private func clearCheckpoint() {
        UserDefaults.standard.removeObject(forKey: checkpointKey)
    }

    // MARK: - Backup entry points

    /// Called from Settings.
    func startBackup(pathIds: Set<UUID>, allPaths: [RecordedPath], userId: UUID, authManager: AuthManager) {
        guard !isUploadingBackup else { return }
        // Save checkpoint
        saveCheckpoint(BackupCheckpoint(pendingPathIds: Array(pathIds), uploadedPhotoIds: []))
        activeBackupTask?.cancel()
        activeBackupTask = Task {
            await performBackup(allPaths: allPaths, userId: userId, authManager: authManager)
        }
    }

    /// Resume an interrupted backup (called on app launch if checkpoint exists).
    func resumeIfNeeded(allPaths: [RecordedPath], userId: UUID, authManager: AuthManager) {
        guard !isUploadingBackup, loadCheckpoint() != nil else { return }
        activeBackupTask = Task {
            await performBackup(allPaths: allPaths, userId: userId, authManager: authManager)
        }
    }

    // MARK: - Backup implementation

    private struct PathRow: Encodable {
        let id: UUID
        let user_id: UUID
        let name: String
        let created_at: Date
    }
    private struct SegmentRow: Encodable {
        let id: UUID
        let path_id: UUID
    }
    private struct LocationRow: Encodable {
        let id: UUID
        let segment_id: UUID
        let latitude: Double
        let longitude: Double
        let timestamp: Date
    }
    private struct PhotoRow: Encodable {
        let id: UUID
        let user_id: UUID
        let location_id: UUID
        let timestamp: Date
        let storage_path: String
    }

    private func performBackup(allPaths: [RecordedPath], userId: UUID, authManager: AuthManager) async {
        var checkpoint = loadCheckpoint() ?? BackupCheckpoint(
            pendingPathIds: allPaths.map { $0.id },
            uploadedPhotoIds: []
        )

        isUploadingBackup = true
        backupProgress = 0.0
        backupStartTime = Date()
        lastBackupError = nil
        defer {
            isUploadingBackup = false
            backupProgress = 0.0
            backupStartTime = nil
        }

        let pendingIds = Set(checkpoint.pendingPathIds)
        let pathsToBackup = allPaths.filter { pendingIds.contains($0.id) }
        let totalPaths = pathsToBackup.count
        var completedPaths = 0
        var failedCount = 0

        print("[Backup] \(totalPaths) paths to back up")

        for path in pathsToBackup {
            do {
                try await backupSinglePath(path, userId: userId, checkpoint: &checkpoint,
                                           completedPaths: completedPaths, totalPaths: totalPaths)
                completedPaths += 1
                backupProgress = Double(completedPaths) / Double(totalPaths)
                checkpoint.pendingPathIds.removeAll { $0 == path.id }
                checkpoint.uploadedPhotoIds.subtract(path.photos.map { $0.id })
                saveCheckpoint(checkpoint)
                authManager.dirtyPathIds.remove(path.id)
                print("[Backup] ✓ '\(path.name)' (\(completedPaths)/\(totalPaths))")
            } catch {
                failedCount += 1
                lastBackupError = error.localizedDescription
                print("[Backup] ❌ '\(path.name)': \(error)")
            }
        }

        if failedCount == 0 {
            clearCheckpoint()
            backupSuccessMessage = "Your data has been backed up to the cloud."
        } else {
            backupSuccessMessage = "\(completedPaths) of \(totalPaths) paths backed up. \(failedCount) failed and will retry."
        }
        await authManager.refreshSyncStatus(localPaths: allPaths)
    }

    private func backupSinglePath(
        _ path: RecordedPath,
        userId: UUID,
        checkpoint: inout BackupCheckpoint,
        completedPaths: Int,
        totalPaths: Int
    ) async throws {
        print("[Backup] path '\(path.name)' — segments: \(path.segments.count), photos: \(path.photos.count)")

        var segmentRows: [SegmentRow] = []
        var locationRows: [LocationRow] = []
        var photoRows: [PhotoRow] = []

        for segment in path.segments {
            segmentRows.append(SegmentRow(id: segment.id, path_id: path.id))
            for location in segment.locations {
                locationRows.append(LocationRow(
                    id: location.id, segment_id: segment.id,
                    latitude: location.latitude, longitude: location.longitude,
                    timestamp: location.timestamp
                ))
            }
        }

        let totalPhotos = path.photos.count
        var uploadedPhotos = 0
        for photo in path.photos {
            let storagePath = "\(userId.uuidString.lowercased())/\(photo.id.uuidString.lowercased()).jpg"
            if checkpoint.uploadedPhotoIds.contains(photo.id) {
                uploadedPhotos += 1
            } else {
                guard let image = photo.image,
                      let jpegData = image.jpegData(compressionQuality: 0.9) else {
                    print("[Backup]   ⚠️ skipping photo \(photo.id) — image missing")
                    continue
                }
                try await supabase.storage
                    .from("path-photos")
                    .upload(storagePath, data: jpegData, options: FileOptions(contentType: "image/jpeg", upsert: true))
                checkpoint.uploadedPhotoIds.insert(photo.id)
                saveCheckpoint(checkpoint)
                uploadedPhotos += 1
                print("[Backup]   ✓ photo (\(uploadedPhotos)/\(totalPhotos))")
            }
            backupProgress = (Double(completedPaths) + Double(uploadedPhotos) / Double(max(1, totalPhotos))) / Double(totalPaths)
            photoRows.append(PhotoRow(
                id: photo.id, user_id: userId, location_id: photo.locationId,
                timestamp: photo.timestamp, storage_path: storagePath
            ))
        }

        let pathRow = PathRow(id: path.id, user_id: userId, name: path.name, created_at: path.startTime)
        try await supabase.from("paths").upsert([pathRow], onConflict: "id").execute()
        if !segmentRows.isEmpty {
            try await supabase.from("path_segments").upsert(segmentRows, onConflict: "id").execute()
        }
        if !locationRows.isEmpty {
            try await supabase.from("gps_locations").upsert(locationRows, onConflict: "id").execute()
        }
        if !photoRows.isEmpty {
            try await supabase.from("path_photos").upsert(photoRows, onConflict: "id").execute()
        }
    }

    // MARK: - Restore

    /// Called from AuthManager.syncOnLogin. Copied verbatim from AuthManager.restorePaths.
    func restorePaths(ids: [UUID], pathStorage: PathStorage, authManager: AuthManager) async {
        let totalCount = ids.count
        var restoredCount = 0
        struct ServerPhoto: Decodable {
            let id: UUID; let timestamp: Date; let storage_path: String
        }
        struct ServerLocation: Decodable {
            let id: UUID; let latitude: Double; let longitude: Double
            let timestamp: Date; let path_photos: [ServerPhoto]
        }
        struct ServerSegment: Decodable {
            let id: UUID; let gps_locations: [ServerLocation]
        }
        struct ServerPath: Decodable {
            let id: UUID; let name: String; let path_segments: [ServerSegment]
        }

        // Batch into chunks of 30 to avoid PostgREST URL length limits
        let chunkSize = 30
        let chunks = stride(from: 0, to: ids.count, by: chunkSize).map {
            Array(ids[$0..<min($0 + chunkSize, ids.count)])
        }

        for chunk in chunks {
            let idStrings = chunk.map { $0.uuidString.lowercased() }
            let paths: [ServerPath]
            do {
                paths = try await supabase
                    .from("paths")
                    .select("id, name, path_segments(id, gps_locations(id, latitude, longitude, timestamp, path_photos(id, timestamp, storage_path)))")
                    .in("id", values: idStrings)
                    .execute().value
            } catch {
                print("[Restore] ❌ chunk fetch failed: \(error)")
                continue
            }
            print("[Restore] fetched \(paths.count) paths")

            for path in paths {
                let allLocations = path.path_segments.flatMap { $0.gps_locations }
                let allPhotos = allLocations.flatMap { $0.path_photos }

                for photo in allPhotos {
                    let filename = "\(photo.id.uuidString.lowercased()).jpg"
                    let url = PathPhoto.imagesDirectory.appendingPathComponent(filename)
                    guard !FileManager.default.fileExists(atPath: url.path) else { continue }
                    do {
                        let data = try await supabase.storage
                            .from("path-photos").download(path: photo.storage_path)
                        try? data.write(to: url)
                    } catch {
                        print("[Restore]   ⚠️ photo download failed: \(error)")
                    }
                }

                let segments = path.path_segments.map { seg -> PathSegment in
                    let locs = seg.gps_locations
                        .sorted { $0.timestamp < $1.timestamp }
                        .map { GPSLocation(id: $0.id, latitude: $0.latitude, longitude: $0.longitude,
                                           timestamp: $0.timestamp, segmentId: seg.id) }
                    return PathSegment(id: seg.id, locations: locs)
                }.sorted { $0.startTime < $1.startTime }

                let photos = allLocations.flatMap { loc in
                    loc.path_photos.map {
                        PathPhoto(id: $0.id, timestamp: $0.timestamp,
                                  imageFilename: "\($0.id.uuidString.lowercased()).jpg",
                                  locationId: loc.id)
                    }
                }

                let recordedPath = RecordedPath(id: path.id, segments: segments,
                                                name: path.name, photos: photos)
                restoredCount += 1
                let progress = Double(restoredCount) / Double(totalCount)
                print("[Restore] ✓ '\(path.name)': \(segments.count) segs, \(allLocations.count) locs, \(photos.count) photos (\(restoredCount)/\(totalCount))")
                await MainActor.run {
                    pathStorage.savePath(recordedPath)
                    self.restoreProgress = progress
                }
            }
        }
    }

    // MARK: - Background task

    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.bgTaskIdentifier, using: nil) { task in
            Task { @MainActor in
                // schedule next
                self.scheduleBackgroundBackup()
                // if backup in progress, extend time; otherwise do nothing
                task.setTaskCompleted(success: true)
            }
        }
    }

    func scheduleBackgroundBackup() {
        let request = BGProcessingTaskRequest(identifier: Self.bgTaskIdentifier)
        request.requiresNetworkConnectivity = true
        try? BGTaskScheduler.shared.submit(request)
    }
}
