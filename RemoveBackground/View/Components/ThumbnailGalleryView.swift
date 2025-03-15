import SwiftUI

// サムネイルギャラリー表示用のビュー
struct ThumbnailGalleryView: View {
    var images: [ImageData]
    var onTapImage: (ImageData) -> Void
    
    var body: some View {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.7))
            
            // 画像がない場合のプレースホルダー
            if images.isEmpty {
                Text("写真がありません")
                    .foregroundColor(.white)
                    .font(.system(size: 14))
            } else {
                // サムネイル表示
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        // 最新の画像を左に表示するために逆順で表示
                        ForEach(images.reversed()) { imageData in
                            // 処理済み画像があればそれを表示、なければオリジナル画像を表示
                            let displayImage = imageData.processedImage ?? imageData.originalImage
                            
                            Image(uiImage: displayImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                .shadow(radius: 3)
                                .padding(5)
                                .onTapGesture {
                                    print("サムネイルタップ: ID \(imageData.id)")
                                    print("画像サイズ: \(imageData.originalImage.size)")
                                    print("処理済み画像: \(imageData.processedImage != nil ? "あり" : "なし")")
                                    onTapImage(imageData)
                                }
                        }
                    }
                    .padding(.horizontal, 10)
                }
            }
        }
        .frame(height: 120)
        .id("thumbnail-gallery-\(images.count)")
    }
} 