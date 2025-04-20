import SwiftUI
import Vision

/// Vision関連のユーティリティ
enum VisionUtils {
    
    // UIImage.Orientation → CGImagePropertyOrientation の変換拡張
    static func cgImageOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
    
    /// Chaikin smoothing – 1回の反復で曲線を滑らかにする
    static func chaikin(_ pts: [CGPoint]) -> [CGPoint] {
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
    
    // シルエット外周だけ返す関数
    static func silhouettePath(from mask: CGImage,
                              orientation uiOrient: UIImage.Orientation) -> CGPath? {
        // マスクに処理済み画像と同じ向きを指定
        let cgOrientation = cgImageOrientation(from: uiOrient)
        let request = VNDetectContoursRequest()
        request.maximumImageDimension = 512
        request.detectsDarkOnLight = false   // 白前景 / 黒背景
        
        let handler = VNImageRequestHandler(cgImage: mask,
                                           orientation: cgOrientation,
                                           options: [:])
        
        try? handler.perform([request])
        guard let obs = request.results?.first else { return nil }
        
        let mut = CGMutablePath()
        for top in obs.topLevelContours {
            // SIMD2<Float> → CGPoint に変換
            var pts: [CGPoint] = top.normalizedPoints.map {
                CGPoint(x: CGFloat($0.x), y: CGFloat($0.y))
            }
            
            // Chaikinは1〜2回程度に減らす（後でstrokingWithWidthで滑らかになるため）
            for _ in 0..<2 { pts = chaikin(pts) }
            
            // 点列から UIBezierPath を作成
            let b = UIBezierPath()
            b.move(to: pts[0])
            pts.dropFirst().forEach { b.addLine(to: $0) }
            b.close()
            
            mut.addPath(b.cgPath)
        }
        return mut.copy()
    }
    
    // Visionから得られたCGPathをSwiftUIのPathに変換し、サイズ調整する関数
    static func createSwiftUIPath(from cgPath: CGPath,
                                 geomSize: CGSize,
                                 imgSize: CGSize) -> Path {
        // アスペクト比を維持して画像が収まるスケールを求める
        let scale = min(geomSize.width / imgSize.width,
                       geomSize.height / imgSize.height)
        
        // 画像が中央に来るようにオフセットを求める
        let drawnWidth = imgSize.width * scale
        let drawnHeight = imgSize.height * scale
        let offsetX = (geomSize.width - drawnWidth) / 2
        let offsetY = (geomSize.height - drawnHeight) / 2
        
        // Vision座標(0-1) → SwiftUI座標への変換
        var transform = CGAffineTransform.identity
            .translatedBy(x: offsetX, y: offsetY + drawnHeight) // Y軸反転の前に移動
            .scaledBy(x: drawnWidth, y: -drawnHeight)          // 上下反転 + スケール
        
        guard let tPath = cgPath.copy(using: &transform) else {
            return Path()
        }
        
        return Path(tPath)
    }
} 