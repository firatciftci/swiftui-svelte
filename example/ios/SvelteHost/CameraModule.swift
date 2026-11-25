import SvelteSwiftUI
import UIKit

@MainActor
enum CameraModule {
    static var module: NativeModule {
        NativeModule("camera")
            .function("isAvailable") { () -> Bool in
                UIImagePickerController.isSourceTypeAvailable(.camera)
            }
            .function("takePhoto") { () async throws -> String? in
                guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                    throw NativeModuleError(code: "unavailable", message: "This device doesn't have a camera.")
                }
                guard let image = await PhotoPicker.take(), let data = image.jpegData(compressionQuality: 0.8) else {
                    return nil
                }
                let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).jpg")
                try data.write(to: url)
                return url.absoluteString
            }
    }
}

@MainActor
private final class PhotoPicker: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private var continuation: CheckedContinuation<UIImage?, Never>?
    private static var current: PhotoPicker?

    static func take() async -> UIImage? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var presenter = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
        while let presented = presenter?.presentedViewController { presenter = presented }
        guard let presenter else { return nil }
        let picker = PhotoPicker()
        current = picker
        return await withCheckedContinuation { continuation in
            picker.continuation = continuation
            let controller = UIImagePickerController()
            controller.sourceType = .camera
            controller.delegate = picker
            presenter.present(controller, animated: true)
        }
    }

    func imagePickerController(
        _ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        finish(picker, with: info[.originalImage] as? UIImage)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        finish(picker, with: nil)
    }

    private func finish(_ picker: UIImagePickerController, with image: UIImage?) {
        picker.dismiss(animated: true)
        continuation?.resume(returning: image)
        continuation = nil
        Self.current = nil
    }
}
