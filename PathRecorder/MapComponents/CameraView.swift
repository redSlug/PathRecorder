import SwiftUI
import UIKit

struct CameraView: UIViewControllerRepresentable {
    // Listen for app background notification and dismiss camera if needed
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.modalPresentationStyle = .fullScreen
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(context.coordinator.handleAppDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        return picker
    }
    @Binding var isPresented: Bool
    var onImageCaptured: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // noop, isPresented manages visibility of the camera
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        @objc func handleAppDidEnterBackground() {
            print("[CameraView] App sent to background, dismissing camera.")
            DispatchQueue.main.async {
                self.parent.isPresented = false
            }
        }
        let parent: CameraView
        init(_ parent: CameraView) {
            self.parent = parent
        }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            print("[CameraView] didFinishPickingMediaWithInfo called")
            let image = info[.originalImage] as? UIImage
            let fixedImage = image.flatMap { Self.fixOrientation($0) }
            if let fixedImage = fixedImage {
                print("[CameraView] Photo captured, calling onImageCaptured.")
                parent.onImageCaptured(fixedImage)
            } else {
                print("[CameraView] No image captured.")
            }
            DispatchQueue.main.async {
                self.parent.isPresented = false
            }
        }

        // Helper to fix image orientation for landscape photos
        static func fixOrientation(_ image: UIImage) -> UIImage {
            if image.imageOrientation == .up {
                return image
            }
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
            return normalizedImage
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("[CameraView] Camera cancelled, dismissing.")
            DispatchQueue.main.async {
                self.parent.isPresented = false
            }
        }
    }
}
