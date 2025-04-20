import SwiftUI
import PhotosUI
import Vision // VisionUtilsを使用するためインポート

// MARK: - ThumbnailItemView
struct ThumbnailItemView: View {
    @ObservedObject var imageData: ImageData          // ← ImageDataクラスの変更を監視
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            contentForCurrentIndex() // index に応じて表示切替
                .frame(width: 80, height: 80) // サイズを固定
                .clipShape(RoundedRectangle(cornerRadius: 10))

            // 削除ボタン
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 1.5)
            }
            .buttonStyle(PlainButtonStyle()) // ボタンのデフォルトスタイルを解除
            .padding(4)
        }
        // 共通のサムネイルスタイルを適用
        .thumbnailModifier(onTap: onTap)
    }

    // imageData.selectedImageIndex に応じてコンテンツを表示
    @ViewBuilder
    private func contentForCurrentIndex() -> some View {
        switch imageData.selectedImageIndex {
        case 0 where imageData.hasProcessedImage:
            // ステッカー風表示 (ImageViewerと同様のロジックで描画)
            GeometryReader { geo in
                ZStack { // 背景とステッカー要素を重ねるためのZStack
                    // まず80x80全体に白背景を敷く
                    Color.white

                    // マスクと処理済み画像があり、シルエットパスが取得できればステッカー描画
                    if let mask = imageData.maskCGImage,
                       let processed = imageData.processedImage,
                       let cgPath = VisionUtils.silhouettePath(
                           from: mask,
                           orientation: processed.imageOrientation) {

                        let swiftUIPath = VisionUtils.createSwiftUIPath(
                            from: cgPath,
                            geomSize: geo.size,
                            imgSize: processed.size)

                        let outline = swiftUIPath.cgPath.copy(
                            strokingWithWidth: 10,
                            lineCap: .round,
                            lineJoin: .round,
                            miterLimit: 10,
                            transform: .identity)

                        // 白フチを描画 (これを直接ZStackに入れる)
                        Path(outline)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.35),
                                    radius: 2, x: 0, y: 1)

                        // 処理済み画像を上に重ねる (これも直接ZStackに入れる)
                        Image(uiImage: processed)
                            .resizable()
                            .aspectRatio(contentMode: .fit)

                    } else {
                        // パスが取得できない場合のフォールバック (白背景上の画像)
                        // Color.white は既に背景にあるので不要
                        if let processed = imageData.processedImage {
                            Image(uiImage: processed)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(8)
                        }
                    }
                }
            }

        case 1 where imageData.hasProcessedImage:
            // 処理済み画像表示 (白背景 + processedImage)
            ZStack {
                Color.white // 背景を白に
                if let thumb = imageData.processedImage {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }

        default: // case 2 または processedImage がない場合
            // オリジナル画像表示
            Image(uiImage: imageData.originalImage)
                .resizable()
                .aspectRatio(contentMode: .fill) // fillで枠いっぱいに表示
        }
    }
}

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
                            // 画像がある場合は ThumbnailItemView を使用
                            let imageData = images.reversed()[index]
                            ThumbnailItemView(
                                imageData: imageData,
                                onTap: {
                                    logTapInfo(imageData)
                                    onTapImage(imageData)
                                },
                                onDelete: {
                                    onDeleteImage(imageData)
                                }
                            )
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
        print("選択中インデックス: \(imageData.selectedImageIndex)") // 選択中のインデックスもログ出力
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
