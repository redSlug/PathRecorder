import SwiftUI
import MapKit

/// Displays a map with polylines and GPS point annotations for a recorded path.
struct PathMapView: View {
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

    var body: some View {
        MapWithPolylines(
            region: region,
            locations: recordedPath.locations,
            pathSegments: pathSegments
        )
        .navigationTitle(pathStorage.path(for: recordedPath.id)?.name ?? editedName)
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
                    var updatedPath = recordedPath
                    updatedPath.editName(editedName)
                    recordedPath = updatedPath
                    pathStorage.updatePath(updatedPath)
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
                Spacer()
            }
            .padding(.bottom, 12)
            .presentationDetents([.fraction(0.25)])
            .onDisappear {
                // Reset editedName to match storage if not saved
                if let latest = pathStorage.path(for: recordedPath.id) {
                    editedName = latest.name
                }
            }
        }
    }
}
