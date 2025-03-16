import SwiftUI
import PhotosUI
import UIKit

struct CameraView: View {
    @StateObject var viewModel = CameraViewModel()
    @State private var imageViewModel: ImageViewModel?
    @State private var isImagePickerPresented = false
    
    var body: some View {
        ZStack {
            // 背景色を黒に設定
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            // カメラプレビュー
            CameraPreview(cameraManager: viewModel.cameraManager)
                .edgesIgnoringSafeArea(.all)
            
            // UI要素
            VStack {
                // 上部コントロール
                HStack {
                    // 背景自動削除トグル
                    Toggle(isOn: $viewModel.isAutoRemoveBackground) {
                        Text("背景自動削除")
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(20)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 50)
                
                Spacer()
                
                // 撮影ボタン
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
                
                // サムネイルギャラリー
                ThumbnailGalleryView(
                    images: viewModel.cameraManager.savedImages,
                    onTapImage: { imageData in
                        // ImageViewModelを作成
                        self.imageViewModel = ImageViewModel(imageData: imageData)
                        viewModel.isImageViewerPresented = true
                    },
                    onDeleteImage: { imageData in
                        // 画像削除
                        viewModel.deleteImage(imageData)
                    },
                    onTapAlbum: {
                        // 写真選択画面を表示
                        isImagePickerPresented = true
                    }
                )
            }
            
            // 撮影時のフラッシュ効果
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
                    imageViewModel: imageViewModel,
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

// UIImagePickerControllerを使用した写真選択
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