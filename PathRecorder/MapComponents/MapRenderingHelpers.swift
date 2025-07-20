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
    static var cachedGlowingBlueDotImage: UIImage? = {
        let size: CGFloat = 32
        let dotRadius: CGFloat = 8
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), false, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        // Draw glow
        let glowColor = UIColor.blue.withAlphaComponent(0.3).cgColor
        ctx.setFillColor(glowColor)
        ctx.addEllipse(in: CGRect(x: (size-dotRadius*3)/2, y: (size-dotRadius*3)/2, width: dotRadius*3, height: dotRadius*3))
        ctx.fillPath()
        // Draw solid blue dot
        let dotColor = UIColor.blue.cgColor
        ctx.setFillColor(dotColor)
        ctx.addEllipse(in: CGRect(x: (size-dotRadius)/2, y: (size-dotRadius)/2, width: dotRadius, height: dotRadius))
        ctx.fillPath()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }()
} 