import SwiftUI
import Combine

// 画像データを管理するViewModel
class ImageViewModel: ObservableObject {
    @Published var imageData: ImageData
    @Published var isProcessing = false
    @Published var showOriginal = false
    
    init(imageData: ImageData) {
        self.imageData = imageData
        // 処理済み画像がある場合は、最初に処理済み画像を表示
        self.showOriginal = imageData.processedImage == nil
    }
    
    // 処理済み画像を更新
    func updateProcessedImage(_ image: UIImage) {
        imageData.processedImage = image
        showOriginal = false
        objectWillChange.send()
    }
    
    // 画像表示を切り替え
    func toggleImageDisplay() {
        if hasProcessedImage {
            withAnimation {
                showOriginal.toggle()
            }
        }
    }
    
    // 非同期で背景削除処理を実行
    func removeBackgroundAsync() {
        guard !isProcessing else { return }
        
        isProcessing = true
        
        Task {
            // バックグラウンドスレッドで処理
            let processedImage = await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    let result = ImageProcessor.processImageWithBackgroundRemoval(self.imageData.originalImage)
                    continuation.resume(returning: result)
                }
            }
            
            // UI更新はメインスレッドで
            await MainActor.run {
                isProcessing = false
                if let processedImage = processedImage {
                    // 処理済み画像を設定
                    updateProcessedImage(processedImage)
                }
            }
        }
    }
    
    // 表示する画像を取得
    var displayImage: UIImage {
        return showOriginal ? imageData.originalImage : (imageData.processedImage ?? imageData.originalImage)
    }
    
    // 処理済み画像があるかどうか
    var hasProcessedImage: Bool {
        return imageData.processedImage != nil
    }
} 