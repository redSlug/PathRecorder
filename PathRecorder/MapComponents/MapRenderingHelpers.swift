import UIKit
import MapKit

struct MapRenderingHelpers {
static func photoAnnotationImage(preview: UIImage?) -> UIImage? {
    let width: CGFloat = 40
    let height: CGFloat = 48
    let bubbleRect = CGRect(x: 0, y: 0, width: width, height: height - 10)
    let tipHeight: CGFloat = 10
    UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0.0)
    guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
    // Draw bubble
    let bubblePath = UIBezierPath(roundedRect: bubbleRect, cornerRadius: 12)
    ctx.setFillColor(UIColor.blue.cgColor)
    ctx.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.15).cgColor)
    bubblePath.fill()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.setStrokeColor(UIColor.blue.cgColor)
    ctx.setLineWidth(2)
    bubblePath.stroke()
    // Draw tip (triangle)
    let tipPath = UIBezierPath()
    tipPath.move(to: CGPoint(x: width/2 - 6, y: height - tipHeight))
    tipPath.addLine(to: CGPoint(x: width/2, y: height))
    tipPath.addLine(to: CGPoint(x: width/2 + 6, y: height - tipHeight))
    tipPath.close()
    ctx.setFillColor(UIColor.blue.cgColor)
    ctx.setStrokeColor(UIColor.blue.cgColor)
    tipPath.fill()
    tipPath.stroke()
    // Draw photo preview inside bubble
    if let preview = preview {
        let previewRect = CGRect(x: (width-28)/2, y: 6, width: 28, height: 28)
        let path = UIBezierPath(roundedRect: previewRect, cornerRadius: 6)
        ctx.saveGState()
        path.addClip()
        preview.draw(in: previewRect)
        ctx.restoreGState()
        // Add border to preview
        ctx.setStrokeColor(UIColor.lightGray.cgColor)
        ctx.setLineWidth(1)
        path.stroke()
    } else {
        // fallback to photo icon if no preview
        if let baseImage = UIImage(systemName: "photo")?.withTintColor(.red, renderingMode: .alwaysOriginal) {
            baseImage.draw(in: CGRect(x: (width-20)/2, y: 8, width: 20, height: 20))
        }
    }
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
}
    static let polylineWidth: CGFloat = 5.0
    static func polylineRenderer(for overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.blue
            renderer.lineWidth = polylineWidth
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
    static var cachedBlueDotImage: UIImage? = {
        let size: CGFloat = 32
        let dotRadius: CGFloat = polylineWidth
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), false, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
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