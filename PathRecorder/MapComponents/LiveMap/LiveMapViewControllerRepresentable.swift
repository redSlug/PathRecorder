import SwiftUI
import MapKit

struct LiveMapViewControllerRepresentable: UIViewControllerRepresentable {
    @Binding var region: MKCoordinateRegion?
    var locations: [GPSLocation]
    var isAutoCentering: Bool
    var isPaused: Bool = false
    var onUserInteraction: (() -> Void)? = nil
    var onMapTouched: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> LiveMapViewController {
        let vc = LiveMapViewController()
        vc.delegate = context.coordinator
        if let region = region {
            vc.setRegion(region, animated: false)
        }
        vc.setLocations(locations)
        vc.setIsAutoCentering(isAutoCentering)
        vc.setIsPaused(isPaused)
        return vc
    }

    func updateUIViewController(_ vc: LiveMapViewController, context: Context) {
        vc.setIsAutoCentering(isAutoCentering)
        vc.setIsPaused(isPaused)
        vc.setLocations(locations)
        if isAutoCentering, let region = region {
            vc.setRegion(region, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, LiveMapViewControllerDelegate {
        var parent: LiveMapViewControllerRepresentable
        init(_ parent: LiveMapViewControllerRepresentable) {
            self.parent = parent
        }
        func regionDidChange(_ region: MKCoordinateRegion, userInitiated: Bool) {
            if userInitiated {
                parent.onUserInteraction?()
            }
            DispatchQueue.main.async {
                self.parent.region = region
            }
        }
        func mapTouched(at coordinate: CLLocationCoordinate2D, point: CGPoint) {
            parent.onMapTouched?()
        }
    }
} 