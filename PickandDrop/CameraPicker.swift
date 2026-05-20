//
//  CameraPicker.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/20/26.
//

import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {

    @Binding var image: UIImage?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(
        context: Context
    ) -> UIImagePickerController {

        let picker = UIImagePickerController()

        picker.sourceType = .camera
        picker.delegate = context.coordinator

        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) {

    }

    class Coordinator:
        NSObject,
        UINavigationControllerDelegate,
        UIImagePickerControllerDelegate {

        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info:
            [UIImagePickerController.InfoKey : Any]
        ) {

            if let image =
                info[.originalImage] as? UIImage {

                parent.image = image
            }

            picker.dismiss(animated: true)
        }
    }
}
