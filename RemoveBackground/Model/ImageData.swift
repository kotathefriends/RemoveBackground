import SwiftUI

// 画像データモデル
struct ImageData: Identifiable, Hashable {
    let id = UUID()
    var originalImage: UIImage
    var processedImage: UIImage?
    var maskCGImage: CGImage?     // シルエットマスク画像を追加
    
    // Hashableプロトコルの実装
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Equatableプロトコルの実装
    static func == (lhs: ImageData, rhs: ImageData) -> Bool {
        return lhs.id == rhs.id
    }
    
    // 処理済み画像があるかどうかを返す
    var hasProcessedImage: Bool {
        return processedImage != nil
    }
    
    // 表示用の画像を返す（処理済み画像があればそれを、なければオリジナル画像を返す）
    var displayImage: UIImage {
        return processedImage ?? originalImage
    }
    
    // 初期化時にオリジナル画像のみを指定するイニシャライザ
    init(originalImage: UIImage, processedImage: UIImage? = nil, maskCGImage: CGImage? = nil) {
        self.originalImage = originalImage
        self.processedImage = processedImage
        self.maskCGImage = maskCGImage
    }
} 