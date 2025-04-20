import SwiftUI

// ImageDisplayable プロトコルはクラスには直接適用できないため、一旦削除します。
// 必要であれば、各ビューで ImageData のプロパティを直接参照するように変更します。

// 画像データモデル (クラスに変更)
final class ImageData: Identifiable, ObservableObject { // class に変更し、ObservableObject に準拠
    let id = UUID()
    @Published var originalImage: UIImage
    @Published var processedImage: UIImage?
    @Published var maskCGImage: CGImage?     // シルエットマスク画像を追加
    
    /// 写真ごとに覚えておきたいタブ番号
    @Published var selectedImageIndex: Int        // 0:Sticker 1:Processed 2:Original
    
    // Equatableプロトコルの実装 (Identifiableがあれば == は id比較で代替可能)
    static func == (lhs: ImageData, rhs: ImageData) -> Bool {
        return lhs.id == rhs.id
    }
    
    // 処理済み画像があるかどうかを返す
    var hasProcessedImage: Bool {
        return processedImage != nil
    }
    
    /// 以前と互換の計算プロパティ (表示用の画像を返す)
    var displayImage: UIImage {
        processedImage ?? originalImage
    }
    
    // 初期化時にオリジナル画像のみを指定するイニシャライザ
    init(originalImage: UIImage, processedImage: UIImage? = nil, maskCGImage: CGImage? = nil, selectedImageIndex: Int = 0) {
        self.originalImage = originalImage
        self.processedImage = processedImage
        self.maskCGImage = maskCGImage
        self.selectedImageIndex = selectedImageIndex
    }
} 