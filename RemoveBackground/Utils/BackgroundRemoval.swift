import SwiftUI
import Vision

/// 背景除去機能を提供するユーティリティ
@available(iOS 18.0, *)
class BackgroundRemoval {
    /// 画像の背景を除去して透明背景の画像を返す
    /// - Parameter image: 処理する元画像
    /// - Returns: 背景が除去された画像
    static func removeBackground(from image: UIImage) async -> UIImage {
        // ローカルのUIImageからCIImageを取得
        guard let ciImage = CIImage(image: image) else {
            print("CIImageの変換に失敗しました")
            return UIImage()
        }
        
        // ImageRequestHandlerの生成
        let imageRequestHandler = ImageRequestHandler(ciImage)
        
        // GenerateForegroundInstanceMaskRequestの生成
        let request = GenerateForegroundInstanceMaskRequest()
        
        // セッション開始（非同期実行）
        if let result = try? await request.perform(on: ciImage) {
            // IndexSetをresult.allInstancesにすると背景以外が表示される
            if let buffer = try? result.generateMaskedImage(
                for: result.allInstances, 
                imageFrom: imageRequestHandler,
                croppedToInstancesExtent: false
            ) {
                // bufferをCVPixelBufferからUIImageに変換
                if let resultImage = UIImage(pixelBuffer: buffer) {
                    return resultImage
                }
            }
        }
        
        // 処理に失敗した場合は空のUIImageを返す
        return UIImage()
    }
}

// MARK: - UIImage拡張

extension UIImage {
    // CVPixelBufferからUIImageを生成する便利イニシャライザ
    convenience init?(pixelBuffer: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        self.init(cgImage: cgImage)
    }
}
