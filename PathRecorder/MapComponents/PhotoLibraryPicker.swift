import SwiftUI
import PhotosUI

struct PhotoLibraryPicker: View {
    @Binding var pathPhotos: [PathPhoto]
    var recordedPath: RecordedPath
    var pathSegments: [PathSegment]
    var onComplete: () -> Void
    @State private var selectedItems: [PhotosPickerItem] = []
    var body: some View {
        PhotosPicker(
            selection: $selectedItems,
            matching: .images,
            photoLibrary: .shared()
        ) {
            Text("Select Photos from Library")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(color: Color.blue.opacity(0.2), radius: 2, x: 0, y: 2)
                .padding(.horizontal)
        }
        .onChange(of: selectedItems, perform: { newItems in
            Task {
                var pending: [PathPhoto] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        // Attach asset if possible
                        var creationDate: Date? = nil
                        if let assetId = item.itemIdentifier,
                           let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil).firstObject {
                            creationDate = asset.creationDate
                        }
                        if let creationDate = creationDate {
                            for segment in pathSegments {
                                let segmentLocations = recordedPath.locations.filter { $0.segmentId == segment.id }
                                guard let first = segmentLocations.first, let last = segmentLocations.last else { continue }
                                if creationDate >= first.timestamp && creationDate <= last.timestamp {
                                    let closest = segmentLocations.min(by: { abs($0.timestamp.timeIntervalSince(creationDate)) < abs($1.timestamp.timeIntervalSince(creationDate)) })
                                    if let closestLocation = closest {
                                        var filename = "photo_\(UUID().uuidString).jpg"
                                        if let assetId = item.itemIdentifier,
                                           let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil).firstObject {
                                            if let resource = PHAssetResource.assetResources(for: asset).first {
                                                filename = resource.originalFilename
                                            }
                                        }
                                        let pathPhoto = PathPhoto(
                                            coordinate: CLLocationCoordinate2D(latitude: closestLocation.latitude, longitude: closestLocation.longitude),
                                            timestamp: creationDate,
                                            image: image,
                                            imageFilename: filename
                                        )
                                        pending.append(pathPhoto)
                                    }
                                    break
                                }
                            }
                        }
                    }
                }
                pathPhotos = pending
                onComplete()
            }
        })
    }
}

// Helper to attach PHAsset to UIImage
extension UIImage {
    private struct AssociatedKeys {
        static var asset = "asset"
    }
    var asset: PHAsset? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.asset) as? PHAsset
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.asset, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
