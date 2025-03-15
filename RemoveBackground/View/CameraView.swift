import SwiftUI

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if viewModel.cameraManager.isError {
                    // エラー表示
                    VStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .resizable()
                            .frame(width: 80, height: 70)
                            .foregroundColor(.yellow)
                            .padding()
                        
                        Text(viewModel.cameraManager.errorMessage)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button("設定を開く") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(20)
                    .padding(30)
                    
                } else {
                    VStack(spacing: 0) {
                        // カメラプレビューエリア - 固定サイズで上部に配置
                        ZStack {
                            // カメラプレビュー
                            CameraPreview(cameraManager: viewModel.cameraManager)
                                .aspectRatio(3/4, contentMode: .fit)
                                .frame(width: geometry.size.width)
                                .frame(height: geometry.size.height * 0.75) // 画面の75%の高さに固定
                                .padding(.top, 20) // 上部に余白を追加
                                .clipped() // はみ出た部分をクリップ
                            
                            // 撮影した写真（フラッシュ効果）
                            if viewModel.cameraManager.isTaken, let _ = viewModel.cameraManager.capturedImage {
                                Color.white
                                    .opacity(0.3)
                                    .frame(width: geometry.size.width, height: geometry.size.height * 0.75)
                                    .transition(.opacity)
                                    .animation(.easeOut(duration: 0.1), value: viewModel.cameraManager.isTaken)
                            }
                            
                            // 撮影ボタン - 固定位置に配置
                            VStack {
                                Spacer()
                                
                                // 背景自動削除の切り替えスイッチ
                                Toggle(isOn: $viewModel.isAutoRemoveBackground) {
                                    Text("背景を自動削除")
                                        .foregroundColor(.white)
                                        .font(.system(size: 14))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(15)
                                .padding(.bottom, 10)
                                
                                Button(action: {
                                    viewModel.takePicture()
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 70, height: 70)
                                        
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                            .frame(width: 80, height: 80)
                                    }
                                }
                                .buttonStyle(InstantButtonStyle())
                                .padding(.bottom, 20)
                            }
                        }
                        
                        Spacer()
                        
                        // 撮影した写真のサムネイル表示エリア - 常に固定サイズで表示
                        ThumbnailGalleryView(
                            images: viewModel.cameraManager.savedImages,
                            onTapImage: { image, index in
                                viewModel.onTapImage(image: image, index: index)
                            }
                        )
                        .frame(height: 120) // 固定高さ
                        // 画像配列の内容が変わったときに確実に更新されるようにIDを設定
                        .id("thumbnailGallery-\(viewModel.cameraManager.savedImages.count)-\(viewModel.cameraManager.savedImages.hashValue)")
                    }
                    .edgesIgnoringSafeArea(.all)
                }
            }
        }
        .onAppear {
            // カメラセッションが開始されていない場合は開始
            viewModel.startCameraSession()
        }
        .onDisappear {
            viewModel.stopCameraSession()
        }
        .sheet(item: $viewModel.selectedImageData) { imageData in
            ImageViewer(image: imageData.image, isPresented: .constant(true), showRemoveBackgroundButton: !viewModel.isAutoRemoveBackground)
                .onAppear {
                    print("シート表示: 画像サイズ \(imageData.image.size)")
                    print("シート表示前の確認: インデックス \(imageData.index), 画像サイズ \(imageData.image.size)")
                    
                    // 画像の参照が失われないように、明示的に保持する
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // 画像が表示されていることを確認
                        print("シート表示後の確認: 画像サイズ \(imageData.image.size)")
                    }
                }
        }
    }
} 