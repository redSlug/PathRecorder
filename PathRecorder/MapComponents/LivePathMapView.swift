import SwiftUI
import MapKit

struct LivePathMapView: View {
    @ObservedObject var locationManager: LocationManager
    @State private var region: MKCoordinateRegion?
    @State private var isAutoCentering: Bool = true
    @State private var lastCenterTime: Date = Date()
    @State private var lastCenterLocation: CLLocationCoordinate2D?
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        if let currentLocation = locationManager.currentLocation {
            _region = State(initialValue: MKCoordinateRegion(
                center: currentLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        } else {
            _region = State(initialValue: nil)
        }
    }
    
    private func centerOnCurrentLocation() {
        guard isAutoCentering,
              let currentLocation = locationManager.currentLocation,
              Date().timeIntervalSince(lastCenterTime) > 0.5 else { return }
        
        if let lastLocation = lastCenterLocation,
           currentLocation.coordinate.distance(from: lastLocation) < 5 {
            return
        }
        
        let newRegion = MKCoordinateRegion(
            center: currentLocation.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
        )
        
        if region == nil || region!.isSignificantlyDifferent(from: newRegion, threshold: 0.0005) {
            region = newRegion
            lastCenterTime = Date()
            lastCenterLocation = currentLocation.coordinate
        }
    }
    
    var body: some View {
        ZStack {
            if let region = region {
                LiveMapViewControllerRepresentable(
                    region: $region,
                    locations: locationManager.locations,
                    isAutoCentering: isAutoCentering
                )
                .onChange(of: locationManager.locations.count) { _ in
                    centerOnCurrentLocation()
                }
                .onChange(of: locationManager.locations) { _ in
                    centerOnCurrentLocation()
                }
                .onChange(of: locationManager.isPaused) { isPaused in
                    if !isPaused && !isAutoCentering {
                        lastCenterTime = Date().addingTimeInterval(-1)
                        isAutoCentering = true
                        if let currentLocation = locationManager.currentLocation {
                            self.region = MKCoordinateRegion(
                                center: currentLocation.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
                            )
                            lastCenterLocation = currentLocation.coordinate
                            lastCenterTime = Date()
                        }
                    }
                }
                .onAppear {
                    centerOnCurrentLocation()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Force a fresh region update immediately on resume
                    lastCenterTime = Date().addingTimeInterval(-1)
                    centerOnCurrentLocation()
                }
            } else {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Waiting for GPS location...")
                        .padding(.top)
                        .foregroundColor(.secondary)
                }
                .onAppear {
                    centerOnCurrentLocation()
                }
                .onChange(of: locationManager.currentLocation) { _ in
                    centerOnCurrentLocation()
                }
                .onChange(of: locationManager.isPaused) { isPaused in
                    if !isPaused && !isAutoCentering {
                        lastCenterTime = Date().addingTimeInterval(-1)
                        isAutoCentering = true
                        if let currentLocation = locationManager.currentLocation {
                            self.region = MKCoordinateRegion(
                                center: currentLocation.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
                            )
                            lastCenterLocation = currentLocation.coordinate
                            lastCenterTime = Date()
                        }
                    }
                }
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isAutoCentering.toggle()
                        if isAutoCentering, let currentLocation = locationManager.currentLocation {
                            self.region = MKCoordinateRegion(
                                center: currentLocation.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
                            )
                            lastCenterLocation = currentLocation.coordinate
                            lastCenterTime = Date()
                        }
                    }) {
                        Image(systemName: isAutoCentering ? "location.slash.fill" : "location.fill")
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