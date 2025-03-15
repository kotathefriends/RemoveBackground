import SwiftUI

// 画像データモデル
struct ImageData: Identifiable {
    let id: UUID
    let image: UIImage
    let index: Int
} 