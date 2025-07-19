import UIKit
import MapKit

struct MapRenderingHelpers {
    static func polylineRenderer(for overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.blue
            renderer.lineWidth = 5.0
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    static var cachedBlueCircleImage: UIImage? = {
        let size: CGFloat = 8
        let circleView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        circleView.backgroundColor = UIColor.blue
        circleView.layer.cornerRadius = size / 2
        UIGraphicsBeginImageContextWithOptions(circleView.bounds.size, false, 0)
        circleView.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }()
} 