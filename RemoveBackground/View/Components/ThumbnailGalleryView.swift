import SwiftUI
import PhotosUI

// サムネイルギャラリー表示用のビュー
struct ThumbnailGalleryView: View {
    var images: [ImageData]
    var onTapImage: (ImageData) -> Void
    var onDeleteImage: (ImageData) -> Void
    var onTapAlbum: () -> Void // アルバムボタンタップ時のコールバック
    
    var body: some View {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.7))
            
            // サムネイル表示
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    // アルバムボタン（常に一番左に固定）
                    Button(action: {
                        onTapAlbum()
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                .shadow(radius: 3)
                            
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                        .padding(5)
                    }
                    
                    // 常に表示する5つの枠組み
                    ForEach(0..<5, id: \.self) { index in
                        // インデックスに対応する画像があるかチェック
                        if index < images.count {
                            // 画像がある場合はサムネイルを表示
                            let imageData = images.reversed()[index]
                            thumbnailView(for: imageData)
                        } else {
                            // 画像がない場合は空の枠を表示
                            emptyThumbnailFrame()
                        }
                    }
                }
                .padding(.horizontal, 10)
            }
        }
        .frame(height: 120)
        .id("thumbnail-gallery-\(images.count)")
    }
    
    // サムネイル表示ビューを生成
    private func thumbnailView(for imageData: ImageData) -> some View {
        let displayImage = imageData.displayImage
        
        return ZStack(alignment: .topTrailing) {
            // 処理済み画像の場合は白背景を追加
            if imageData.hasProcessedImage {
                ZStack {
                    // 白背景
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .frame(width: 80, height: 80)
                    
                    // 処理済み画像
                    Image(uiImage: displayImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .thumbnailModifier(onTap: {
                    logTapInfo(imageData)
                    onTapImage(imageData)
                })
            } else {
                // 元画像はそのまま表示
                Image(uiImage: displayImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .thumbnailModifier(onTap: {
                        logTapInfo(imageData)
                        onTapImage(imageData)
                    })
            }
            
            // 削除ボタン
            Button(action: {
                onDeleteImage(imageData)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 1.5, x: 0, y: 0)
            }
            .padding(5)
        }
    }
    
    // 空のサムネイルフレームを生成
    private func emptyThumbnailFrame() -> some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(Color.white.opacity(0.5), lineWidth: 2)
            .frame(width: 80, height: 80)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 3)
            .padding(5)
    }
    
    // タップ情報をログに出力
    private func logTapInfo(_ imageData: ImageData) {
        print("サムネイルタップ: ID \(imageData.id)")
        print("画像サイズ: \(imageData.originalImage.size)")
        print("処理済み画像: \(imageData.hasProcessedImage ? "あり" : "なし")")
    }
}

// 共通のサムネイルスタイル修飾子
extension View {
    func thumbnailModifier(onTap: @escaping () -> Void) -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(radius: 3)
            .padding(5)
            .onTapGesture(perform: onTap)
    }
} 