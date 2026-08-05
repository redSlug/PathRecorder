import Foundation
import Combine

final class PathStorage: ObservableObject {
    func path(for id: UUID) -> RecordedPath? {
        recordedPaths.first(where: { $0.id == id })
    }

    @Published var recordedPaths: [RecordedPath] = []
    @Published var lastUpdatedPathId: UUID? = nil
    private let userDefaults = UserDefaults.standard
    private let key = "RecordedPaths"

    init() {
        loadPaths()
    }

    func savePath(_ path: RecordedPath) {
        if let index = recordedPaths.firstIndex(where: { $0.id == path.id }) {
            recordedPaths[index] = path
        } else {
            recordedPaths.append(path)
        }
        saveToUserDefaults()
    }

    func deletePath(id: UUID) {
        recordedPaths.removeAll { $0.id == id }
        saveToUserDefaults()
    }

    func updatePath(_ path: RecordedPath) {
        if let index = recordedPaths.firstIndex(where: { $0.id == path.id }) {
            let existing = recordedPaths[index]
            guard existing.name != path.name || existing.photos != path.photos else { return }
            recordedPaths[index] = path
            saveToUserDefaults()
            lastUpdatedPathId = path.id
        }
    }

    func deletePhoto(from pathId: UUID, photo: PathPhoto) {
        if let index = recordedPaths.firstIndex(where: { $0.id == pathId }) {
            let originalCount = recordedPaths[index].photos.count
            recordedPaths[index].photos.removeAll { $0.id == photo.id }
            guard recordedPaths[index].photos.count != originalCount else { return }
            // Delete image file from disk
            let url = PathPhoto.imagesDirectory.appendingPathComponent(photo.imageFilename)
            try? FileManager.default.removeItem(at: url)
            saveToUserDefaults()
            lastUpdatedPathId = pathId
        }
    }

    private func saveToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(recordedPaths) {
            userDefaults.set(encoded, forKey: key)
        }
    }

    /// Export the stored paths as a JSON file and return a file URL to the temporary file.
    /// Returns `nil` if encoding or writing fails.
    func exportJSONToTemporaryFile() -> URL? {
        guard let data = try? JSONEncoder().encode(recordedPaths) else { return nil }
        let tmpDir = FileManager.default.temporaryDirectory
        let filename = "PathRecorderExport-\(Int(Date().timeIntervalSince1970)).json"
        let url = tmpDir.appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private func loadPaths() {
        if let data = userDefaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([RecordedPath].self, from: data) {
            recordedPaths = decoded
        }
    }
}
