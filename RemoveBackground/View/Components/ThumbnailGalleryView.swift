import SwiftUI

// サムネイルギャラリーコンテナ - 常に一定の高さを確保
struct ThumbnailGalleryView: View {
    let images: [UIImage]
    var onTapImage: (UIImage, Int) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 区切り線
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(height: 1)
            
            // サムネイルギャラリー（空でも高さを確保）
            ZStack {
                // 背景
                Color.black.opacity(0.5)
                
                // サムネイル（画像がある場合のみ表示）
                if !images.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 10) {
                            // 配列を逆順に処理して新しい写真を左側に表示
                            ForEach(Array(images.enumerated().reversed()), id: \.0) { index, image in
                                // 画像表示
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                                    .onTapGesture {
                                        // 実際の配列内のインデックスを計算
                                        let actualIndex = images.count - 1 - index
                                        print("タップされた画像インデックス: \(actualIndex)")
                                        print("配列の長さ: \(images.count)")
                                        
                                        // 直接画像を取得して渡す
                                        print("タップされた画像のサイズ: \(image.size)")
                                        
                                        // 配列内の全画像のサイズを出力（デバッグ用）
                                        print("--- 配列内の全画像情報 ---")
                                        for (i, img) in images.enumerated() {
                                            print("インデックス \(i): サイズ \(img.size)")
                                        }
                                        print("-------------------------")
                                        
                                        onTapImage(image, actualIndex)
                                    }
                                    // 一意のIDを生成（より確実に更新を検知するため）
                                    .id("thumbnail-\(index)-\(image.hashValue)")
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
                } else {
                    // 画像がない場合のプレースホルダー
                    Text("撮影した写真がここに表示されます")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
        }
    }
} 