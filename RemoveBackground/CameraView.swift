import SwiftUI

struct CameraView: View {
    @StateObject var cameraManager = CameraManager()
    
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
                            if cameraManager.isTaken, let image = cameraManager.capturedImage {
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
                        ThumbnailGalleryContainer(images: cameraManager.savedImages)
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

// サムネイルギャラリーコンテナ - 常に一定の高さを確保
struct ThumbnailGalleryContainer: View {
    let images: [UIImage]
    
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
                                Image(uiImage: images[images.count - 1 - index]) // 新しい写真を左側に表示
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
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
