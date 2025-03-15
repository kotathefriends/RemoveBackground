import SwiftUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

// 背景削除ユーティリティクラス
class BackgroundRemoval {
    // 背景削除機能を追加
    static func removeBackground(from image: UIImage) -> UIImage? {
        guard let inputImage = CIImage(image: image) else {
            print("CIImageの作成に失敗しました")
            return nil
        }
        
        // 元の画像の向きを保存
        let originalOrientation = image.imageOrientation
        
        // マスク生成処理
        guard let maskImage = createMask(from: inputImage) else {
            print("マスクの作成に失敗しました")
            return nil
        }
        
        let outputImage = applyMask(mask: maskImage, to: inputImage)
        return convertToUIImage(ciImage: outputImage, orientation: originalOrientation)
    }

    // マスク生成
    private static func createMask(from inputImage: CIImage) -> CIImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(ciImage: inputImage)
        
        do {
            try handler.perform([request])
            
            if let result = request.results?.first {
                do {
                    print("マスク生成: インスタンス数 \(result.allInstances.count)")
                    let mask = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
                    print("マスク生成成功: サイズ \(CVPixelBufferGetWidth(mask))x\(CVPixelBufferGetHeight(mask))")
                    return CIImage(cvPixelBuffer: mask)
                } catch {
                    print("マスク生成エラー (スケーリング): \(error)")
                    return nil
                }
            } else {
                print("マスク生成エラー: 結果がありません")
                return nil
            }
        } catch {
            print("マスク生成エラー (リクエスト実行): \(error)")
            return nil
        }
    }

    // マスク適用
    private static func applyMask(mask: CIImage, to image: CIImage) -> CIImage {
        // 白い背景を作成
        let whiteBackground = CIImage(color: CIColor(red: 1, green: 1, blue: 1))
            .cropped(to: image.extent)
        
        let filter = CIFilter.blendWithMask()
        filter.inputImage = image
        filter.maskImage = mask
        filter.backgroundImage = whiteBackground // 黒（空）から白の背景に変更
        
        guard let outputImage = filter.outputImage else {
            print("マスク適用エラー: フィルター出力がnilです")
            return image // エラー時は元の画像を返す
        }
        
        return outputImage
    }

    // CIImageをUIImageに変換
    private static func convertToUIImage(ciImage: CIImage, orientation: UIImage.Orientation = .up) -> UIImage {
        let context = CIContext(options: nil)
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("CGImage変換エラー: CGImageの作成に失敗しました")
            return UIImage() // 空の画像を返す
        }
        
        // 元の画像の向きを適用
        let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
        print("UIImage変換成功: サイズ \(uiImage.size)")
        return uiImage
    }
} 