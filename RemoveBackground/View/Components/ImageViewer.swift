import SwiftUI
import Vision // Visionフレームワークをインポート

// UIImage.Orientation → CGImagePropertyOrientation の変換拡張
extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

// MARK: - Chaikinアルゴリズムによる曲線の滑らか化
/// Chaikin smoothing – 1回の反復で曲線を滑らかにする
func chaikin(_ pts: [CGPoint]) -> [CGPoint] {
    guard pts.count > 2 else { return pts }
    var out: [CGPoint] = [pts[0]]
    for i in 0..<pts.count - 1 {
        let p0 = pts[i], p1 = pts[i+1]
        let q = CGPoint(x: 0.75*p0.x + 0.25*p1.x,
                       y: 0.75*p0.y + 0.25*p1.y)
        let r = CGPoint(x: 0.25*p0.x + 0.75*p1.x,
                       y: 0.25*p0.y + 0.75*p1.y)
        out.append(contentsOf: [q, r])
    }
    out.append(pts.last!)
    return out
}

struct ImageViewer: View {
    @ObservedObject var viewModel: ImageViewModel
    @Binding var isPresented: Bool
    @State private var showControls = true
    @State private var selectedImageIndex = 0 // 表示する画像のインデックス
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if showControls {
                    // 画像切り替えインジケーター
                    if viewModel.hasProcessedImage {
                        HStack(spacing: 4) {
                            // 処理済み画像1（白背景）
                            Rectangle()
                                .fill(selectedImageIndex == 0 ? Color.white : Color.white.opacity(0.5))
                                .frame(height: 3)
                                .onTapGesture {
                                    selectedImageIndex = 0
                                }
                            
                            // 処理済み画像2（白背景）
                            Rectangle()
                                .fill(selectedImageIndex == 1 ? Color.white : Color.white.opacity(0.5))
                                .frame(height: 3)
                                .onTapGesture {
                                    selectedImageIndex = 1
                                }
                            
                            // 元画像
                            Rectangle()
                                .fill(selectedImageIndex == 2 ? Color.white : Color.white.opacity(0.5))
                                .frame(height: 3)
                                .onTapGesture {
                                    selectedImageIndex = 2
                                }
                        }
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
                
                // 画像表示部分
                ZStack {
                    // 選択されたインデックスに応じて画像を表示
                    if viewModel.hasProcessedImage {
                        if selectedImageIndex == 0 {
                            // 処理済み画像1（ステッカー風）- Visionで輪郭描画
                            GeometryReader { geometry in // サイズ取得
                                ZStack {
                                    // 背景色 (白)
                                    Color.white
                                        .aspectRatio(viewModel.imageData.processedImage?.size ?? CGSize(width: 1, height: 1), contentMode: .fit) // 画像のアスペクト比に合わせる
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                    
                                    // 輪郭パスを描画
                                    if geometry.size.width > 0 && geometry.size.height > 0 {
                                        if let mask = viewModel.imageData.maskCGImage,
                                           let processed = viewModel.imageData.processedImage,
                                           let cgPath = silhouettePath(from: mask,
                                                                      orientation: processed.imageOrientation) {
                                            
                                            // 処理前のサイズとオリエンテーションをログ
                                            let _ = print("DEBUG-BEFORE imageOrientation: \(processed.imageOrientation.rawValue), size: \(processed.size)")
                                            
                                            // 画像のピクセル向きでサイズを決定
                                            let pixelSize = processed.size    // ★ 元の画像サイズをそのまま使用
                                            
                                            // 処理後のピクセルサイズをログ
                                            let _ = print("DEBUG‑IMG  orientation: \(processed.imageOrientation.rawValue)  "
                                                + "pixelSize: \(pixelSize)")
                                            
                                            // ① ステッカー用パスを取得
                                            let swiftUIPath = createSwiftUIPath(
                                                from: cgPath,
                                                geomSize: geometry.size,
                                                imgSize: pixelSize
                                            )
                                            
                                            // ② ステッカー用の外枠パスを生成
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
                                    } else {
                                        let _ = print("DEBUG: GeometryReader size is zero, skipping path drawing.")
                                    }
                                }
                            }
                            .aspectRatio(viewModel.imageData.processedImage?.size ?? CGSize(width: 1, height: 1), contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            
                        } else if selectedImageIndex == 1 {
                            // 処理済み画像2（白背景、枠線なし）
                            ZStack {
                                // 白背景（3:4のアスペクト比）
                                Color.white
                                    .aspectRatio(3/4, contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                
                                // 処理済み画像（枠線なし）
                                Image(uiImage: viewModel.imageData.processedImage!)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        } else {
                            // 元画像
                            Image(uiImage: viewModel.imageData.originalImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else {
                        // 処理済み画像がない場合は元画像を表示
                        Image(uiImage: viewModel.imageData.originalImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    // タップジェスチャーを追加
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if viewModel.hasProcessedImage {
                                withAnimation {
                                    selectedImageIndex = (selectedImageIndex + 1) % 3
                                }
                            }
                        }
                        .onLongPressGesture(minimumDuration: 0.3) {
                            withAnimation {
                                showControls.toggle()
                            }
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                if viewModel.isProcessing && showControls {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            // 画面表示時に自動的に背景削除を開始
            if !viewModel.hasProcessedImage && !viewModel.isProcessing {
                viewModel.removeBackgroundAsync()
            }
        }
    }
    
    // MARK: シルエット外周だけ返す関数
    private func silhouettePath(from mask: CGImage,
                               orientation uiOrient: UIImage.Orientation) -> CGPath? {
        // ★★ ここでログ ★★
        let cgOrientation = CGImagePropertyOrientation(uiOrient)
        print("DEBUG‑PATH cgOrientation: \(cgOrientation.rawValue)  "
              + "uiOrientation: \(uiOrient.rawValue)")
        
        let request = VNDetectContoursRequest()
        request.maximumImageDimension = 512
        request.detectsDarkOnLight = false   // 白前景 / 黒背景
        
        // ★ マスクに処理済み画像と同じ向きを指定
        let handler = VNImageRequestHandler(cgImage: mask,
                                            orientation: cgOrientation,
                                            options: [:])
        
        try? handler.perform([request])
        guard let obs = request.results?.first else { return nil }
        
        let mut = CGMutablePath()
        for top in obs.topLevelContours {
            // ① SIMD2<Float> → CGPoint に変換
            var pts: [CGPoint] = top.normalizedPoints.map {
                CGPoint(x: CGFloat($0.x), y: CGFloat($0.y))
            }
            
            // ② Chaikinは1〜2回程度に減らす（後でstrokingWithWidthで滑らかになるため）
            for _ in 0..<2 { pts = chaikin(pts) }
            
            // ③ 点列から UIBezierPath を作成
            let b = UIBezierPath()
            b.move(to: pts[0])
            pts.dropFirst().forEach { b.addLine(to: $0) }
            b.close()
            
            mut.addPath(b.cgPath)
        }
        return mut.copy()
    }
    
    // Visionから得られたCGPathをSwiftUIのPathに変換し、サイズ調整する関数
    /// - Parameters:
    ///   - cgPath: Visionが返したnormalizedPath
    ///   - geomSize: GeometryReaderが返す枠のサイズ
    ///   - imgSize: 実際のUIImage.size
    private func createSwiftUIPath(from cgPath: CGPath,
                                   geomSize: CGSize,
                                   imgSize: CGSize) -> Path {
        print("DEBUG‑PATH2 geom: \(geomSize)  imgSize: \(imgSize)")
        print("DEBUG: createSwiftUIPath - Converting CGPath with geomSize: \(geomSize), imgSize: \(imgSize)")
        
        // ① アスペクト比を維持して画像が収まるスケールを求める
        let scale = min(geomSize.width / imgSize.width,
                        geomSize.height / imgSize.height)
        
        // ② 画像が中央に来るようにオフセットを求める
        let drawnWidth = imgSize.width * scale
        let drawnHeight = imgSize.height * scale
        let offsetX = (geomSize.width - drawnWidth) / 2
        let offsetY = (geomSize.height - drawnHeight) / 2
        
        print("DEBUG: Scale: \(scale), Offsets: X=\(offsetX), Y=\(offsetY), Drawn size: \(drawnWidth)x\(drawnHeight)")
        
        // ③ Vision座標(0-1) → SwiftUI座標への変換
        var transform = CGAffineTransform.identity
            .translatedBy(x: offsetX, y: offsetY + drawnHeight) // Y軸反転の前に移動
            .scaledBy(x: drawnWidth, y: -drawnHeight)          // 上下反転 + スケール
        
        guard let tPath = cgPath.copy(using: &transform) else {
            print("DEBUG: Failed to transform path")
            return Path()
        }
        
        print("DEBUG: Path conversion successful. New bounding box: \(tPath.boundingBox)")
        return Path(tPath)
    }
}
