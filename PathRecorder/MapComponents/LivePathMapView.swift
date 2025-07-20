import SwiftUI
import MapKit

struct LivePathMapView: View {
    @ObservedObject var locationManager: LocationManager
    @State private var region: MKCoordinateRegion?
    @State private var isAutoCentering: Bool = true
    @State private var lastCenterLocation: CLLocationCoordinate2D?
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        updateRegion()
    }
    
    private func updateRegion() {
        // Only update region if a valid location is available
        if let currentLocation = locationManager.currentLocation, !locationManager.isPaused {
            region = MKCoordinateRegion(
                center: currentLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
            )
        } else if let lastLocation = locationManager.lastRecordedLocation {
            region = MKCoordinateRegion(
                center: lastLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
            )
        }
    }
    
    var body: some View {
        ZStack {
            LiveMapViewControllerRepresentable(
                region: $region,
                locations: locationManager.locations,
                isAutoCentering: isAutoCentering,
                onMapTouched: {
                    isAutoCentering = false
                }
            )
            .onChange(of: locationManager.locations.count) { _ in
                if isAutoCentering {
                    updateRegion()
                }
            }
            .onChange(of: locationManager.isPaused) { isPaused in
                isAutoCentering = true
                updateRegion()
            }
            .onAppear {
                isAutoCentering = true
                updateRegion()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                isAutoCentering = true
                updateRegion()
            }

            // Show GPS loading overlay if region is nil
            if region == nil {
                VStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                    Text("Waiting for GPS...")
                        .font(.headline)
                        .padding(.top, 8)
                    Spacer()
                }
                .background(Color.white.opacity(0.7))
            }

            // Only show button when auto-centering is disabled
            if !isAutoCentering {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            isAutoCentering = true
                            updateRegion()
                        }) {
                            Image(systemName: "location.fill")
                                .padding()
                                .background(Color.white.opacity(0.8))
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        .padding()
                        .opacity(region != nil ? 1 : 0.5)
                        .disabled(region == nil)
                    }
                    Spacer()
                }
            }
        }
    }
}
