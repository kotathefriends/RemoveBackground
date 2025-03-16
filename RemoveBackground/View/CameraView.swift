import SwiftUI
import PhotosUI
import UIKit

struct CameraView: View {
    @StateObject var viewModel = CameraViewModel()
    @State private var imageViewModel: ImageViewModel?
    @State private var isImagePickerPresented = false
    
    var body: some View {
        ZStack {
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            CameraPreview(cameraManager: viewModel.cameraManager)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                Button(action: {
                    viewModel.takePicture()
                }) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.8), lineWidth: 2)
                                .frame(width: 60, height: 60)
                        )
                }
                .buttonStyle(InstantButtonStyle())
                .padding(.bottom, 30)
                
                ThumbnailGalleryView(
                    images: viewModel.cameraManager.savedImages,
                    onTapImage: { imageData in
                        self.imageViewModel = ImageViewModel(imageData: imageData)
                        viewModel.isImageViewerPresented = true
                    },
                    onDeleteImage: { imageData in
                        viewModel.deleteImage(imageData)
                    },
                    onTapAlbum: {
                        isImagePickerPresented = true
                    }
                )
            }
            
            if viewModel.cameraManager.isTaken {
                Color.white
                    .edgesIgnoringSafeArea(.all)
                    .opacity(0.3)
            }
        }
        .onAppear {
            viewModel.startCameraSession()
        }
        .onDisappear {
            viewModel.stopCameraSession()
        }
        .sheet(isPresented: $viewModel.isImageViewerPresented) {
            if let imageViewModel = self.imageViewModel {
                ImageViewer(
                    viewModel: imageViewModel,
                    isPresented: $viewModel.isImageViewerPresented
                )
            }
        }
        .sheet(isPresented: $isImagePickerPresented) {
            ImagePicker(onImageSelected: { image in
                if let image = image {
                    viewModel.addImageFromLibrary(image)
                }
            })
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    var onImageSelected: (UIImage?) -> Void
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            } else {
                parent.onImageSelected(nil)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onImageSelected(nil)
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
} 