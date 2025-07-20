import SwiftUI
import MapKit

/// Displays a map with polylines and GPS point annotations for a recorded path.
struct PathMapView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sheetDetent: PresentationDetent = .fraction(0.25)
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var pathStorage: PathStorage
    @State private var region: MKCoordinateRegion
    @State private var pathSegments: [PathSegment] = []
    @State private var isEditingName = false
    @State private var editedName: String
    @State private var recordedPath: RecordedPath
    var showRenameSheetOnAppear: Bool

    init(recordedPath: RecordedPath, locationManager: LocationManager, pathStorage: PathStorage, showRenameSheetOnAppear: Bool = false) {
        self.locationManager = locationManager
        self.pathStorage = pathStorage
        _recordedPath = State(initialValue: recordedPath)
        // Group locations by segment first
        let segments = Dictionary(grouping: recordedPath.locations, by: { $0.segmentId })
        let pathSegments = segments.map { segmentId, locations in
            PathSegment(
                id: segmentId,
                coordinates: locations
                    .sorted(by: { $0.timestamp < $1.timestamp })
                    .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            )
        }
        _pathSegments = State(initialValue: pathSegments)
        // Calculate the proper region to fit all coordinates
        let allCoordinates = pathSegments.flatMap { $0.coordinates }
        let minLat = allCoordinates.map { $0.latitude }.min() ?? 0
        let maxLat = allCoordinates.map { $0.latitude }.max() ?? 0
        let minLon = allCoordinates.map { $0.longitude }.min() ?? 0
        let maxLon = allCoordinates.map { $0.longitude }.max() ?? 0
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let latDelta = (maxLat - minLat) * 1.2
        let lonDelta = (maxLon - minLon) * 1.2
        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(
                latitudeDelta: max(latDelta, 0.001),
                longitudeDelta: max(lonDelta, 0.001)
            )
        )
        _region = State(initialValue: initialRegion)
        _editedName = State(initialValue: recordedPath.name)
        self.showRenameSheetOnAppear = showRenameSheetOnAppear
    }

    // Holds all photos at a tapped coordinate
    @State private var selectedPhotos: [PathPhoto]? = nil
    @State private var selectedPhotoIndex: Int = 0

    var body: some View {
        let currentPath = pathStorage.path(for: recordedPath.id) ?? recordedPath
        MapWithPolylines(
            region: region,
            locations: currentPath.locations,
            pathSegments: pathSegments,
            photos: currentPath.photos,
            onPhotoTapped: { tappedPhoto in
                // Always get the most current path data when a photo is tapped
                let latestPath = pathStorage.path(for: recordedPath.id) ?? recordedPath
                
                // Find all photos within 10 meters of the tapped coordinate
                let tappedLocation = CLLocation(latitude: tappedPhoto.coordinate.latitude, longitude: tappedPhoto.coordinate.longitude)
                let nearbyPhotos = latestPath.photos.filter {
                    let photoLocation = CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
                    return tappedLocation.distance(from: photoLocation) <= 10.0 // meters
                }
                selectedPhotos = nearbyPhotos
                // Show the tapped photo first if multiple (only if it still exists)
                if let idx = nearbyPhotos.firstIndex(where: { $0.id == tappedPhoto.id }) {
                    selectedPhotoIndex = idx
                } else {
                    selectedPhotoIndex = 0
                }
            }
        )
        .id(currentPath.photos.count) // Force refresh when photo count changes
        .navigationTitle(currentPath.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    isEditingName = true
                }) {
                    Image(systemName: "pencil")
                }
            }
        }
        .onAppear {
            if showRenameSheetOnAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isEditingName = true
                }
            }
        }
        .sheet(isPresented: $isEditingName) {
            VStack(spacing: 18) {
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
                TextField("Path Name", text: $editedName)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                    )
                    .padding(.horizontal)
                Button(action: {
                    if var currentPath = pathStorage.path(for: recordedPath.id) {
                        currentPath.editName(editedName)
                        pathStorage.updatePath(currentPath)
                        recordedPath = currentPath
                    }
                    isEditingName = false
                }) {
                    Text("Set Name")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(color: Color.accentColor.opacity(0.2), radius: 2, x: 0, y: 2)
                }
                .padding(.horizontal)
                .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if sheetDetent == .medium {
                    Button(role: .destructive, action: {
                        pathStorage.deletePath(id: recordedPath.id)
                        isEditingName = false
                        dismiss()
                    }) {
                        Text("Delete Path")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(color: Color.red.opacity(0.2), radius: 2, x: 0, y: 2)
                    }
                    .padding(.horizontal)
                }
                Spacer()
            }
            .padding(.bottom, 12)
            .presentationDetents([.fraction(0.25), .medium], selection: $sheetDetent)
            .onDisappear {
                // Reset editedName to match storage if not saved
                if let latest = pathStorage.path(for: recordedPath.id) {
                    editedName = latest.name
                    recordedPath = latest
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedPhotos != nil },
            set: { if !$0 { selectedPhotos = nil } }
        )) {
            if let photos = selectedPhotos {
                PhotoPagerView(
                    photos: photos, 
                    selectedIndex: $selectedPhotoIndex,
                    onDeletePhoto: { photoToDelete in
                        // Get the current path from storage
                        if var currentPath = pathStorage.path(for: recordedPath.id) {
                            // Remove photo from the path
                            currentPath.deletePhoto(photoToDelete)
                            
                            // Update the stored path
                            pathStorage.updatePath(currentPath)
                            
                            // Update the local recordedPath state as well
                            recordedPath = currentPath
                            
                            // Update the selected photos list with the latest data
                            selectedPhotos?.removeAll { $0.id == photoToDelete.id }
                            
                            // If no photos left, close the sheet
                            if selectedPhotos?.isEmpty == true {
                                selectedPhotos = nil
                            } else if let remainingPhotos = selectedPhotos {
                                // Adjust selected index if needed
                                if selectedPhotoIndex >= remainingPhotos.count {
                                    selectedPhotoIndex = max(0, remainingPhotos.count - 1)
                                }
                            }
                        }
                    }
                )
            } else {
                Text("No photos at this location.")
                    .padding()
            }
        }
    }
}
