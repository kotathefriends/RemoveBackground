import SwiftUI
import Vision
import CoreImage

/// 背景除去機能を提供するユーティリティ
class BackgroundRemoval {
    /// 画像の背景を除去して透明背景の画像を返す
    /// - Parameter image: 処理する元画像
    /// - Returns: 背景が除去された画像（失敗時はnil）
    static func removeBackground(from image: UIImage) -> UIImage? {
        // ローカルのUIImageからCIImageを取得
        guard let ciImage = CIImage(image: image) else {
            print("CIImageの変換に失敗しました")
            return nil
        }
        
        // 元の画像の向きを保持
        let originalOrientation = image.imageOrientation
        
        // VNImageRequestHandlerの生成
        let handler = VNImageRequestHandler(ciImage: ciImage)
        
        // VNGenerateForegroundInstanceMaskRequestの生成
        let request = VNGenerateForegroundInstanceMaskRequest()
        
        do {
            // リクエストを実行
            try handler.perform([request])
            
            // 結果を取得
            if let observation = request.results?.first {
                // マスクを生成（背景以外の全インスタンス）
                if let mask = try? observation.generateScaledMaskForImage(
                    forInstances: observation.allInstances,
                    from: handler
                ) {
                    // マスクをCIImageに変換
                    let maskImage = CIImage(cvPixelBuffer: mask)
                    
                    // マスクを適用して背景を透明に変更
                    let outputImage = applyMask(mask: maskImage, to: ciImage)
                    
                    // CIImageをUIImageに変換
                    return convertToUIImage(ciImage: outputImage, orientation: originalOrientation)
                }
            }
        } catch {
            print("背景除去処理でエラーが発生: \(error)")
        }
        
        // 処理に失敗した場合はnilを返す
        return nil
    }
    
    /// マスクを使用して画像の背景を透明に変更
    private static func applyMask(mask: CIImage, to image: CIImage) -> CIImage {
        // 透明背景を作成
        let transparentBackground = CIImage.empty()
        
        // マスクを使って前景と透明背景を合成
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else {
            print("マスクブレンドフィルターの作成に失敗しました")
            return image
        }
        
        blendFilter.setValue(image, forKey: kCIInputImageKey)
        blendFilter.setValue(mask, forKey: kCIInputMaskImageKey)
        blendFilter.setValue(transparentBackground, forKey: kCIInputBackgroundImageKey)
        
        guard let outputImage = blendFilter.outputImage else {
            print("マスク適用エラー: フィルター出力がnilです")
            return image
        }
        
        return outputImage
    }
    
    /// CIImageをUIImageに変換
    private static func convertToUIImage(ciImage: CIImage, orientation: UIImage.Orientation = .up) -> UIImage {
        // 高品質な変換を行うためのコンテキストを作成
        let context = CIContext(options: [
            .useSoftwareRenderer: false,
            .highQualityDownsample: true
        ])
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("CGImage変換エラー: CGImageの作成に失敗しました")
            return UIImage()
        }
        
        // 透明度を保持するためのUIImage作成
        let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
        return uiImage
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
    
    // 画像の向きを指定して新しいUIImageを返す
    func withOrientation(_ orientation: UIImage.Orientation) -> UIImage {
        if self.imageOrientation == orientation {
            return self
        }
        guard let cgImage = self.cgImage else { return self }
        return UIImage(cgImage: cgImage, scale: scale, orientation: orientation)
    }
} 


