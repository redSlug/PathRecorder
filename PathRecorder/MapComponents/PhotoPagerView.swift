import SwiftUI

struct PhotoPagerView: View {
    let photos: [PathPhoto] // Replace with your actual model type
    @Binding var selectedIndex: Int
    @State private var showShareSheet = false
    @State private var imageToShare: UIImage?

    var body: some View {
        Group {
            if photos.isEmpty {
                Text("No photos at this location.")
                    .padding()
            } else {
                VStack(spacing: 0) {
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { idx, photo in
                            VStack {
                                if let image = photo.image {
                                    Text(DateFormatter.localizedString(from: photo.timestamp, dateStyle: .medium, timeStyle: .short))
                                        .font(.subheadline)
                                    // Display GPS coordinate in readable format
                                    Text(String(format: "Lat: %.5f, Lon: %.5f", photo.coordinate.latitude, photo.coordinate.longitude))
                                        .font(.caption)
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: 400, maxHeight: 400)
                                        .cornerRadius(16)
                                        .padding()
                                    Button(action: {
                                        print("[PhotoPagerView] Sharing image: size=\(image.size), orientation=\(image.imageOrientation.rawValue), isCGImage=\(image.cgImage != nil), isCIImage=\(image.ciImage != nil)")
                                        imageToShare = image
                                        showShareSheet = true
                                    }) {
                                        Label("Share Photo", systemImage: "square.and.arrow.up")
                                            .font(.headline)
                                    }
                                } else {
                                    Text("Photo unavailable")
                                }
                            }
                            .frame(maxHeight: .infinity)
                            .tag(idx)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                    .frame(maxHeight: .infinity)
                }
                .frame(maxHeight: .infinity)
                .padding()
            }
        }
        .sheet(item: $imageToShare) { image in
            ShareSheet(activityItems: [image])
        }
    }

    // UIKit share sheet wrapper
    struct ShareSheet: UIViewControllerRepresentable {
        var activityItems: [Any]
        var applicationActivities: [UIActivity]? = nil

        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        }

        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    }
}

// Make UIImage identifiable for .sheet(item:)
extension UIImage: Identifiable {
    public var id: UUID { UUID() }
}

