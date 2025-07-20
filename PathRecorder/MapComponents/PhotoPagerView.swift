import SwiftUI

struct PhotoPagerView: View {
    let photos: [PathPhoto] // Replace with your actual model type
    @Binding var selectedIndex: Int
    @State private var showShareSheet = false
    @State private var imageToShare: ShareImage?
    @State private var showDeleteAlert = false
    let onDeletePhoto: (PathPhoto) -> Void

    var body: some View {
        Group {
            if photos.isEmpty {
                Text("No photos at this location.")
                    .padding()
            } else {
                ZStack(alignment: .topLeading) {
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
                                        imageToShare = ShareImage(image: image)
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
                    
                    // Delete button in top left corner
                    Button(action: {
                        showDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .font(.title2)
                            .foregroundColor(.red)
                            .padding(12)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding()
                }
            }
        }
        .alert("Delete Photo", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if selectedIndex < photos.count {
                    let photoToDelete = photos[selectedIndex]
                    onDeletePhoto(photoToDelete)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this photo? This action cannot be undone.")
        }
        .sheet(item: $imageToShare) { shareImage in
            ShareSheet(activityItems: [shareImage.image])
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

// Wrapper for sharing images in .sheet(item:)
struct ShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

