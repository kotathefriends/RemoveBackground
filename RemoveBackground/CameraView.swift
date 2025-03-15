import SwiftUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

struct CameraView: View {
    @StateObject var cameraManager = CameraManager()
    @State private var selectedImageData: ImageData? = nil
    @State private var isImageViewerPresented = false
    @State private var isAutoRemoveBackground = true // 背景自動削除フラグ
    
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
                                
                                // 背景自動削除の切り替えスイッチ
                                Toggle(isOn: $isAutoRemoveBackground) {
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
                                    // 撮影前に変数を用意して、撮影後の処理を確実に実行できるようにする
                                    let shouldProcessImage = isAutoRemoveBackground
                                    
                                    // 撮影処理
                                    cameraManager.takePicture()
                                    
                                    // 背景自動削除が有効な場合、撮影後に処理を行う
                                    if shouldProcessImage {
                                        // 撮影後の処理を行うタイミングを調整
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                            // capturedImageを使用して処理
                                            if let capturedImage = cameraManager.capturedImage {
                                                print("撮影後の画像処理を開始: サイズ \(capturedImage.size)")
                                                print("現在の保存画像数: \(cameraManager.savedImages.count)")
                                                
                                                // 最新の画像を処理
                                                if cameraManager.savedImages.count > 0 {
                                                    // 最新の画像を取得
                                                    let lastImage = cameraManager.savedImages.last!
                                                    print("最新の保存画像を処理: サイズ \(lastImage.size)")
                                                    processImageWithBackgroundRemoval(lastImage)
                                                } else {
                                                    // savedImagesが空の場合はcapturedImageを使用
                                                    print("savedImagesが空のため、capturedImageを使用")
                                                    processImageWithBackgroundRemoval(capturedImage)
                                                }
                                            } else {
                                                print("処理する画像が見つかりません: capturedImageがnil")
                                            }
                                        }
                                    }
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
                        .id("thumbnailGallery-\(cameraManager.savedImages.count)-\(Date().timeIntervalSince1970)") // より確実に一意のIDを生成
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
            ImageViewer(image: imageData.image, isPresented: .constant(true), showRemoveBackgroundButton: !isAutoRemoveBackground)
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
    
    // 背景削除処理を行う関数
    private func processImageWithBackgroundRemoval(_ image: UIImage) {
        print("背景自動削除処理を開始します: 元画像サイズ \(image.size)")
        print("処理開始時の保存画像数: \(cameraManager.savedImages.count)")
        if let lastImage = cameraManager.savedImages.last {
            print("処理開始時の最後の画像サイズ: \(lastImage.size)")
        }
        
        Task {
            let processedImage = await withCheckedContinuation({ continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    print("背景削除処理を実行中...")
                    let result = removeBackground(from: image)
                    print("背景削除処理完了: 結果 \(result != nil ? "成功" : "失敗")")
                    if let result = result {
                        print("処理後画像サイズ: \(result.size)")
                    }
                    continuation.resume(returning: result)
                }
            })
            
            // 処理済み画像をカメラマネージャーに保存
            if let processedImage = processedImage {
                DispatchQueue.main.async {
                    print("処理済み画像をカメラマネージャーに適用します")
                    
                    // 現在の保存画像数を記録
                    let currentCount = cameraManager.savedImages.count
                    print("更新前の保存画像数: \(currentCount)")
                    
                    // 現在の画像配列の状態を確認
                    print("--- 更新前の画像配列の状態 ---")
                    for (i, img) in cameraManager.savedImages.enumerated() {
                        print("インデックス \(i): サイズ \(img.size)")
                    }
                    print("------------------------------")
                    
                    // 画像を更新
                    cameraManager.updateLastCapturedImage(with: processedImage)
                    
                    // 画面の更新を強制
                    cameraManager.objectWillChange.send()
                    
                    // 更新後の画像配列の状態を確認
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        print("--- 更新後の画像配列の状態 ---")
                        for (i, img) in cameraManager.savedImages.enumerated() {
                            print("インデックス \(i): サイズ \(img.size)")
                        }
                        print("------------------------------")
                        
                        // サムネイルが更新されたことを確認
                        if let lastImage = cameraManager.savedImages.last {
                            print("更新後のサムネイル画像サイズ: \(lastImage.size)")
                            print("更新後の保存画像数: \(cameraManager.savedImages.count)")
                        }
                    }
                    
                    // サムネイルギャラリーを強制的に更新
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("サムネイルギャラリー強制更新を実行")
                        cameraManager.objectWillChange.send()
                    }
                }
            } else {
                print("背景削除処理に失敗しました")
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
    @State private var processedImage: UIImage?
    @State private var isProcessing = false
    var showRemoveBackgroundButton: Bool = true
    
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
                if let processedImage = processedImage {
                    Image(uiImage: processedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                Spacer()
                
                // 背景削除ボタン（表示フラグがtrueの場合のみ表示）
                if showRemoveBackgroundButton {
                    Button(action: {
                        removeBackgroundAsync()
                    }) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 5)
                            } else {
                                Image(systemName: "scissors")
                                    .font(.system(size: 16))
                            }
                            Text(isProcessing ? "処理中..." : "背景を削除")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                    .disabled(isProcessing || processedImage != nil)
                    .padding(.bottom, 20)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    private func removeBackgroundAsync() {
        isProcessing = true
        
        Task {
            let result = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let result = removeBackground(from: image)
                    continuation.resume(returning: result)
                }
            }
            
            DispatchQueue.main.async {
                self.processedImage = result
                self.isProcessing = false
            }
        }
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
                            // 配列を逆順に処理して新しい写真を左側に表示
                            ForEach(Array(images.enumerated().reversed()), id: \.0) { index, image in
                                // 画像表示
                                Image(uiImage: image)
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
                                        // 実際の配列内のインデックスを計算
                                        let actualIndex = images.count - 1 - index
                                        print("タップされた画像インデックス: \(actualIndex)")
                                        print("配列の長さ: \(images.count)")
                                        
                                        // 直接画像を取得して渡す
                                        print("タップされた画像のサイズ: \(image.size)")
                                        
                                        // 配列内の全画像のサイズを出力（デバッグ用）
                                        print("--- 配列内の全画像情報 ---")
                                        for (i, img) in images.enumerated() {
                                            print("インデックス \(i): サイズ \(img.size)")
                                        }
                                        print("-------------------------")
                                        
                                        onTapImage(image, actualIndex)
                                    }
                                    .id("thumbnail-\(index)-\(Date().timeIntervalSince1970)")
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

// 背景削除機能を追加
func removeBackground(from image: UIImage) -> UIImage? {
    guard let inputImage = CIImage(image: image) else {
        print("CIImageの作成に失敗しました")
        return nil
    }
    
    // 元の画像の向きを保存
    let originalOrientation = image.imageOrientation
    
    // 非同期処理
    guard let maskImage = createMask(from: inputImage) else {
        print("マスクの作成に失敗しました")
        return nil
    }
    
    let outputImage = applyMask(mask: maskImage, to: inputImage)
    return convertToUIImage(ciImage: outputImage, orientation: originalOrientation)
}

// マスク生成
private func createMask(from inputImage: CIImage) -> CIImage? {
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(ciImage: inputImage)
    
    do {
        try handler.perform([request])
        
        if let result = request.results?.first {
            let mask = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
            return CIImage(cvPixelBuffer: mask)
        }
    } catch {
        print("マスク生成エラー: \(error)")
    }
    
    return nil
}

// マスク適用
private func applyMask(mask: CIImage, to image: CIImage) -> CIImage {
    let filter = CIFilter.blendWithMask()
    filter.inputImage = image
    filter.maskImage = mask
    filter.backgroundImage = CIImage.empty()
    
    return filter.outputImage!
}

// CIImageをUIImageに変換
private func convertToUIImage(ciImage: CIImage, orientation: UIImage.Orientation = .up) -> UIImage {
    let context = CIContext(options: nil)
    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
        fatalError("CGImageの作成に失敗しました")
    }
    
    // 元の画像の向きを適用
    let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
    return uiImage
} 
