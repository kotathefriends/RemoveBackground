import SwiftUI
import Vision

// MARK: - メインのImageViewer
struct ImageViewer: View {
    @ObservedObject var viewModel: ImageViewModel
    @Binding var isPresented: Bool
    @State private var showControls = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if showControls {
                    HeaderControls(
                        viewModel: viewModel,
                        selectedImageIndex: $viewModel.selectedImageIndex,
                        isPresented: $isPresented
                    )
                }
                
                // 画像表示部分
                ImageDisplay(
                    viewModel: viewModel,
                    selectedImageIndex: $viewModel.selectedImageIndex,
                    showControls: $showControls
                )
                
                if viewModel.isProcessing && showControls {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            // 画面表示時に自動的に背景削除を開始
            if !viewModel.imageData.hasProcessedImage && !viewModel.isProcessing {
                viewModel.removeBackgroundAsync()
            }
        }
    }
}

// MARK: - ヘッダー部分のコントロール
struct HeaderControls: View {
    @ObservedObject var viewModel: ImageViewModel
    @Binding var selectedImageIndex: Int
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 画像切り替えインジケーター
            if viewModel.imageData.hasProcessedImage {
                ImageIndicator(selectedImageIndex: $selectedImageIndex)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 5)
            }
            
            HStack {
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .padding(.leading)
                
                Spacer()
            }
            .padding(.top, 5)
        }
    }
}

// MARK: - 画像インジケーター
struct ImageIndicator: View {
    @Binding var selectedImageIndex: Int
    
    var body: some View {
        HStack(spacing: 4) {
            // 処理済み画像1（ステッカー風）
            Rectangle()
                .fill(selectedImageIndex == 0 ? Color.white : Color.white.opacity(0.5))
                .frame(height: 3)
                .onTapGesture {
                    selectedImageIndex = 0
                    triggerHapticFeedback()
                }
            
            // 処理済み画像2（白背景、枠線なし）
            Rectangle()
                .fill(selectedImageIndex == 1 ? Color.white : Color.white.opacity(0.5))
                .frame(height: 3)
                .onTapGesture {
                    selectedImageIndex = 1
                    triggerHapticFeedback()
                }
            
            // 元画像
            Rectangle()
                .fill(selectedImageIndex == 2 ? Color.white : Color.white.opacity(0.5))
                .frame(height: 3)
                .onTapGesture {
                    selectedImageIndex = 2
                    triggerHapticFeedback()
                }
        }
    }
    
    // ハプティックフィードバックを生成する関数
    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - 画像表示部分
struct ImageDisplay: View {
    @ObservedObject var viewModel: ImageViewModel
    @Binding var selectedImageIndex: Int
    @Binding var showControls: Bool
    
    // ハプティックフィードバック用ジェネレーター
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .soft)
    
    var body: some View {
        ZStack {
            // 画像表示
            if viewModel.imageData.hasProcessedImage {
                displaySelectedImage()
            } else {
                // 処理済み画像がない場合は元画像を表示
                Image(uiImage: viewModel.imageData.originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // 左右のタップエリア（画像切り替え用）
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // 左側エリア
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: geometry.size.width / 2)
                        .onTapGesture {
                            handleTap(isLeft: true)
                        }
                    
                    // 右側エリア
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: geometry.size.width / 2)
                        .onTapGesture {
                            handleTap(isLeft: false)
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 長押しジェスチャーをZStackに適用
        .onLongPressGesture(minimumDuration: 0.3) {
            withAnimation {
                showControls.toggle()
                hapticGenerator.impactOccurred()
            }
        }
    }
    
    // タップ処理ロジック
    private func handleTap(isLeft: Bool) {
        guard viewModel.imageData.hasProcessedImage else { return }
        
        withAnimation {
            if isLeft {
                selectedImageIndex = (selectedImageIndex - 1 + 3) % 3
            } else {
                selectedImageIndex = (selectedImageIndex + 1) % 3
            }
            hapticGenerator.impactOccurred()
        }
    }
    
    @ViewBuilder
    private func displaySelectedImage() -> some View {
        switch selectedImageIndex {
        case 0:
            StickeredImageView(imageData: viewModel.imageData)
        case 1:
            ProcessedImageView(imageData: viewModel.imageData)
        default:
            Image(uiImage: viewModel.imageData.originalImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - ステッカー風画像表示
struct StickeredImageView: View {
    @ObservedObject var imageData: ImageData
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景色 (白)
                Color.white
                    .aspectRatio(imageData.processedImage?.size ?? CGSize(width: 1, height: 1), contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // 輪郭パスを描画
                if geometry.size.width > 0 && geometry.size.height > 0 {
                    drawStickerWithOutline(geometry: geometry)
                }
            }
        }
        .aspectRatio(imageData.processedImage?.size ?? CGSize(width: 1, height: 1), contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func drawStickerWithOutline(geometry: GeometryProxy) -> some View {
        if let mask = imageData.maskCGImage,
           let processed = imageData.processedImage,
           let cgPath = VisionUtils.silhouettePath(from: mask, orientation: processed.imageOrientation) {
            
            // 画像のピクセル向きでサイズを決定
            let pixelSize = processed.size
            
            // ステッカー用パスを取得
            let swiftUIPath = VisionUtils.createSwiftUIPath(
                from: cgPath,
                geomSize: geometry.size,
                imgSize: pixelSize
            )
            
            // ステッカー用の外枠パスを生成
            let outlinePath = swiftUIPath.cgPath.copy(
                strokingWithWidth: 32,
                lineCap: .round,
                lineJoin: .round,
                miterLimit: 10,
                transform: .identity
            )
            
            ZStack {
                // 先に白フチを塗りつぶす
                Path(outlinePath)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.35),
                            radius: 6, x: 0, y: 4)
                
                // その上に画像を重ねる（内側は隠れない）
                Image(uiImage: processed)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
}

// MARK: - 白背景画像表示
struct ProcessedImageView: View {
    @ObservedObject var imageData: ImageData
    
    var body: some View {
        ZStack {
            // 白背景（3:4のアスペクト比）
            Color.white
                .aspectRatio(3/4, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 処理済み画像（枠線なし）
            if let processedImage = imageData.processedImage {
                Image(uiImage: processedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
