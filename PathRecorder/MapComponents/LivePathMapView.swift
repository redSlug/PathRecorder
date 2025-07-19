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
        if let currentLocation = locationManager.currentLocation {
            region = MKCoordinateRegion(
                center: currentLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
            )
        } else if let lastLocation = locationManager.lastRecordedLocation {
            region = MKCoordinateRegion(
                center: lastLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
            )
        } else {
            region = nil
        }
    }
    
    var body: some View {
        ZStack {
            LiveMapViewControllerRepresentable(
                region: $region,
                locations: locationManager.locations,
                isAutoCentering: isAutoCentering,
                onMapTouched: {
                    // Disable auto-centering when user touches the map
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
