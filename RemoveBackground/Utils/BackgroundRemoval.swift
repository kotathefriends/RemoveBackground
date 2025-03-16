import SwiftUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// 背景削除機能を提供するユーティリティクラス
class BackgroundRemoval {
    /// 画像から背景を削除し、白背景の画像を返す
    /// - Parameter image: 背景削除を行う元画像
    /// - Returns: 背景が削除された画像（失敗時はnil）
    static func removeBackground(from image: UIImage) -> UIImage? {
        // 入力画像をCIImageに変換
        guard let inputImage = CIImage(image: image) else {
            print("CIImageの作成に失敗しました")
            return nil
        }
        
        // 元の画像の向きを保存
        let originalOrientation = image.imageOrientation
        
        // 前景マスクを生成
        guard let maskImage = createMask(from: inputImage) else {
            print("マスクの作成に失敗しました")
            return nil
        }
        
        // マスクを膨らませて境界線を調整
        let dilatedMask = dilateMask(maskImage, radius: 3.0)
        
        // マスクを適用して背景を白に変更
        let outputImage = applyMask(mask: dilatedMask, to: inputImage)
        
        // CIImageをUIImageに変換して返す
        return convertToUIImage(ciImage: outputImage, orientation: originalOrientation)
    }

    /// Vision APIを使用して前景マスクを生成
    /// - Parameter inputImage: 入力画像
    /// - Returns: 前景マスク画像（失敗時はnil）
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

    /// マスクを膨張させて境界線を調整
    /// - Parameters:
    ///   - mask: 入力マスク
    ///   - radius: 膨張半径（大きいほど境界線が外側に広がる）
    /// - Returns: 膨張処理後のマスク
    private static func dilateMask(_ mask: CIImage, radius: CGFloat) -> CIImage {
        guard let dilateFilter = CIFilter(name: "CIMorphologyMaximum") else {
            print("膨張フィルターの作成に失敗しました")
            return mask
        }
        
        dilateFilter.setValue(mask, forKey: kCIInputImageKey)
        dilateFilter.setValue(radius, forKey: "inputRadius")
        
        guard let dilatedMask = dilateFilter.outputImage else {
            print("マスク膨張処理に失敗しました")
            return mask
        }
        
        print("マスク膨張処理完了")
        return dilatedMask
    }

    /// マスクを使用して画像の背景を白に変更
    /// - Parameters:
    ///   - mask: 適用するマスク（白い部分が前景）
    ///   - image: 入力画像
    /// - Returns: 背景が白に変更された画像
    private static func applyMask(mask: CIImage, to image: CIImage) -> CIImage {
        // 白い背景を作成
        let whiteBackground = CIImage(color: CIColor(red: 1, green: 1, blue: 1))
            .cropped(to: image.extent)
        
        // マスクを使って前景と白背景を合成
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else {
            print("マスクブレンドフィルターの作成に失敗しました")
            return image
        }
        
        blendFilter.setValue(image, forKey: kCIInputImageKey)
        blendFilter.setValue(mask, forKey: kCIInputMaskImageKey)
        blendFilter.setValue(whiteBackground, forKey: kCIInputBackgroundImageKey)
        
        guard let outputImage = blendFilter.outputImage else {
            print("マスク適用エラー: フィルター出力がnilです")
            return image
        }
        
        return outputImage
    }

    /// CIImageをUIImageに変換
    /// - Parameters:
    ///   - ciImage: 変換するCIImage
    ///   - orientation: 画像の向き
    /// - Returns: 変換後のUIImage
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
        
        // 元の画像の向きを適用してUIImageを作成
        let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
        print("UIImage変換成功: サイズ \(uiImage.size)")
        return uiImage
    }
} 
