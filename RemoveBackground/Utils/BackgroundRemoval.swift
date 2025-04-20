import SwiftUI
import Vision

/// 背景除去機能を提供するユーティリティ
@available(iOS 18.0, *)
class BackgroundRemoval {
    /// 画像の背景を除去して透明背景の画像とシルエットマスクを返す
    /// - Parameter image: 処理する元画像
    /// - Returns: 背景が除去された画像とシルエットマスク
    static func removeBackground(from image: UIImage) async -> (UIImage, CGImage?) {
        // ローカルのUIImageからCIImageを取得
        guard let ciImage = CIImage(image: image) else {
            print("CIImageの変換に失敗しました")
            return (UIImage(), nil)
        }
        
        // ImageRequestHandlerの生成
        let imageRequestHandler = ImageRequestHandler(ciImage)
        
        // GenerateForegroundInstanceMaskRequestの生成
        let request = GenerateForegroundInstanceMaskRequest()
        
        // セッション開始（非同期実行）
        if let result = try? await request.perform(on: ciImage) {
            // ① 前景だけの UIImage
            let pixelBuffer = try? result.generateMaskedImage(
                for: result.allInstances, 
                imageFrom: imageRequestHandler,
                croppedToInstancesExtent: false
            )
            
            // ② 2値シルエットマスク (CGImage) を取得
            let maskBuffer = try? result.generateScaledMask(
                for: result.allInstances,
                scaledToImageFrom: imageRequestHandler
            )
            
            // ★ 元画像の向きを引き継いでUIImageを生成
            let processed = pixelBuffer.flatMap { 
                UIImage(pixelBuffer: $0,
                       scale: image.scale,
                       orientation: image.imageOrientation)
            } ?? UIImage()
            
            let maskCG = maskBuffer.flatMap { 
                CIContext().createCGImage(
                    CIImage(cvPixelBuffer: $0),
                    from: CGRect(origin: .zero,
                                size: CGSize(width: CVPixelBufferGetWidth($0),
                                            height: CVPixelBufferGetHeight($0)))
                )
            }
            return (processed, maskCG)
        }
        
        // 処理に失敗した場合は空のUIImageとnilを返す
        return (UIImage(), nil)
    }
}

// MARK: - UIImage拡張

extension UIImage {
    /// CVPixelBuffer → UIImage（向きとスケールを指定）
    convenience init?(pixelBuffer: CVPixelBuffer,
                      scale: CGFloat = 1.0,
                      orientation: UIImage.Orientation = .up)
    {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { 
            return nil 
        }
        self.init(cgImage: cgImage, scale: scale, orientation: orientation)
    }
}
