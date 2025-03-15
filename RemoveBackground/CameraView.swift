import SwiftUI

struct CameraView: View {
    @StateObject var cameraManager = CameraManager()
    @State private var selectedImageData: ImageData? = nil
    @State private var isImageViewerPresented = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if cameraManager.isError {
                    // エラー表示
                    VStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .resizable()
                            .frame(width: 80, height: 70)
                            .foregroundColor(.yellow)
                            .padding()
                        
                        Text(cameraManager.errorMessage)
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
                            CameraPreview(cameraManager: cameraManager)
                                .aspectRatio(3/4, contentMode: .fit)
                                .frame(width: geometry.size.width)
                                .frame(height: geometry.size.height * 0.75) // 画面の75%の高さに固定
                                .padding(.top, 20) // 上部に余白を追加
                                .clipped() // はみ出た部分をクリップ
                            
                            // 撮影した写真（フラッシュ効果）
                            if cameraManager.isTaken, let _ = cameraManager.capturedImage {
                                Color.white
                                    .opacity(0.3)
                                    .frame(width: geometry.size.width, height: geometry.size.height * 0.75)
                                    .transition(.opacity)
                                    .animation(.easeOut(duration: 0.1), value: cameraManager.isTaken)
                            }
                            
                            // 撮影ボタン - 固定位置に配置
                            VStack {
                                Spacer()
                                Button(action: {
                                    cameraManager.takePicture()
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
                        ThumbnailGalleryContainer(
                            images: cameraManager.savedImages,
                            onTapImage: { image, index in
                                print("サムネイル写真がタップされました: インデックス \(index)")
                                print("savedImages数: \(cameraManager.savedImages.count)")
                                print("渡された画像のサイズ: \(image.size)")
                                
                                // インデックスが有効かチェック
                                if index >= 0 && index < cameraManager.savedImages.count {
                                    DispatchQueue.main.async {
                                        self.selectedImageData = ImageData(id: UUID(), image: image, index: index)
                                        self.isImageViewerPresented = true
                                    }
                                } else {
                                    print("無効なインデックス: \(index)")
                                }
                            }
                        )
                        .frame(height: 120) // 固定高さ
                    }
                    .edgesIgnoringSafeArea(.all)
                }
            }
        }
        .onAppear {
            // カメラセッションが開始されていない場合は開始
            if !cameraManager.session.isRunning {
                cameraManager.startSession()
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .sheet(item: $selectedImageData) { imageData in
            ImageViewer(image: imageData.image, isPresented: .constant(true))
                .onAppear {
                    print("シート表示: 画像サイズ \(imageData.image.size)")
                    print("シート表示前の確認: インデックス \(imageData.index), 画像サイズ \(imageData.image.size)")
                }
        }
    }
}

// 即時反応するボタンスタイル
struct InstantButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// 写真閲覧ビュー
struct ImageViewer: View {
    let image: UIImage
    @Binding var isPresented: Bool
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                // 閉じるボタン
                HStack {
                    Spacer()
                    Button(action: {
                        print("閉じるボタンがタップされました")
                        isPresented = false
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                
                Spacer()
                
                // 画像表示
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Spacer()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// サムネイルギャラリーコンテナ - 常に一定の高さを確保
struct ThumbnailGalleryContainer: View {
    let images: [UIImage]
    var onTapImage: (UIImage, Int) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 区切り線
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(height: 1)
            
            // サムネイルギャラリー（空でも高さを確保）
            ZStack {
                // 背景
                Color.black.opacity(0.5)
                
                // サムネイル（画像がある場合のみ表示）
                if !images.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 10) {
                            ForEach(0..<images.count, id: \.self) { index in
                                let displayIndex = images.count - 1 - index
                                Image(uiImage: images[displayIndex]) // 新しい写真を左側に表示
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                                    .onTapGesture {
                                        print("タップされた画像インデックス: \(displayIndex)")
                                        print("実際の配列内の位置: \(displayIndex), 配列の長さ: \(images.count)")
                                        
                                        // 直接画像を取得して渡す
                                        let actualImage = images[displayIndex]
                                        print("タップされた画像のサイズ: \(actualImage.size)")
                                        onTapImage(actualImage, displayIndex)
                                    }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
                } else {
                    // 画像がない場合のプレースホルダー
                    Text("撮影した写真がここに表示されます")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
        }
    }
}

// 画像データモデル
struct ImageData: Identifiable {
    let id: UUID
    let image: UIImage
    let index: Int
} 
