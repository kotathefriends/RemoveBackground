import SwiftUI
import Vision

/// 画像の輪郭検出機能を提供するユーティリティ
@available(iOS 18.0, *)
enum ContourDetection {
    
    /// 画像内のオブジェクトの輪郭パスを検出する
    /// - Parameter image: 輪郭を検出する対象の画像（背景透明想定）
    /// - Returns: 検出された輪郭のSwiftUI Path。検出失敗時はnil。
    static func detectContours(from image: UIImage) async -> Path? {
        // UIImageをCIImageに変換
        guard let originalCiImage = CIImage(image: image) else {
            print("CIImageへの変換に失敗しました。")
            return nil
        }
        
        // 色を反転させる
        guard let invertedCiImage = invertColors(of: originalCiImage) else {
            print("色の反転に失敗しました。")
            return nil
        }
        
        // 輪郭検出リクエストの準備
        var request = DetectContoursRequest()
        // コントラスト調整などのパラメータは必要に応じて設定
        request.contrastAdjustment = 1.5 // Stack Overflowの例に合わせた値
        // request.maximumImageDimension = 512 // 必要に応じて画像サイズを制限

        do {
            // 輪郭検出を実行 (色反転した画像に対して)
            // orientationは画像のメタデータに応じて適切に設定するのが望ましい
            // ここでは一旦 .downMirrored を使用
            let contoursObservation = try await request.perform(on: invertedCiImage, orientation: .downMirrored)
            
            // 検出された輪郭 (CGPath) を SwiftUI の Path に変換
            let cgPath = contoursObservation.normalizedPath
            
            // 輪郭が検出されなかった場合（空のパス）はnilを返す
            guard !cgPath.isEmpty else {
                print("輪郭が検出されませんでした。")
                return nil
            }

            return Path(cgPath)
            
        } catch {
            print("輪郭検出中にエラーが発生しました: \(error)")
            return nil
        }
    }

    /// CIImageの色を反転させるヘルパー関数
    private static func invertColors(of ciImage: CIImage) -> CIImage? {
        let invertFilter = CIFilter(name: "CIColorInvert")
        invertFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        return invertFilter?.outputImage
    }
} 
