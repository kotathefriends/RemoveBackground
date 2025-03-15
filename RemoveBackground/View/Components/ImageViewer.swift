import SwiftUI

// 写真閲覧ビュー
struct ImageViewer: View {
    // 参照型として画像データを保持
    @ObservedObject var imageViewModel: ImageViewModel
    @Binding var isPresented: Bool
    @State private var showOriginal = false // 初期値をfalseに変更（背景削除された画像を最初に表示）
    @State private var isProcessing = false
    @State private var showControls = true // コントロールの表示/非表示を管理
    
    var body: some View {
        ZStack {
            // 背景
            Color.black.ignoresSafeArea()
            
            // 画像表示
            VStack(spacing: 0) {
                // インスタグラムストーリーのようなバーUI（コントロールが表示されている場合のみ表示）
                if showControls {
                    HStack(spacing: 4) {
                        // 処理済み画像用のバー（処理済み画像がある場合のみ表示）
                        if imageViewModel.imageData.processedImage != nil {
                            Rectangle()
                                .fill(!showOriginal ? Color.white : Color.white.opacity(0.5))
                                .frame(height: 3)
                                .onTapGesture {
                                    showOriginal = false
                                }
                        }
                        
                        // オリジナル画像用のバー
                        Rectangle()
                            .fill(showOriginal ? Color.white : Color.white.opacity(0.5))
                            .frame(height: 3)
                            .onTapGesture {
                                showOriginal = true
                            }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 5)
                }
                
                // 閉じるボタン（コントロールが表示されている場合のみ表示）
                if showControls {
                    HStack {
                        Button(action: {
                            isPresented = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(.leading)
                        
                        Spacer()
                    }
                    .padding(.top, 5)
                }
                
                Spacer()
                
                // 表示する画像を選択
                let displayImage = showOriginal ? imageViewModel.imageData.originalImage : (imageViewModel.imageData.processedImage ?? imageViewModel.imageData.originalImage)
                
                Image(uiImage: displayImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture {
                        // 画像タップで写真を切り替え（処理済み画像がある場合のみ）
                        if imageViewModel.imageData.processedImage != nil {
                            withAnimation {
                                showOriginal.toggle()
                            }
                        }
                    }
                    // 長押しでコントロールの表示/非表示を切り替え
                    .onLongPressGesture(minimumDuration: 0.3) {
                        withAnimation {
                            showControls.toggle()
                        }
                    }
                
                Spacer()
                
                // 処理済み画像がない場合は背景削除ボタンを表示（コントロールが表示されている場合のみ表示）
                if imageViewModel.imageData.processedImage == nil && showControls {
                    Button(action: {
                        removeBackgroundAsync()
                    }) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 5)
                            }
                            Text("背景を削除")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(20)
                    }
                    .disabled(isProcessing)
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            // 処理済み画像がある場合は、最初に処理済み画像を表示
            if imageViewModel.imageData.processedImage != nil {
                showOriginal = false
            } else {
                showOriginal = true
            }
        }
    }
    
    // 非同期で背景削除処理を実行
    private func removeBackgroundAsync() {
        isProcessing = true
        
        Task {
            // バックグラウンドスレッドで処理
            let processedImage = await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    let result = removeBackground(from: imageViewModel.imageData.originalImage)
                    continuation.resume(returning: result)
                }
            }
            
            // UI更新はメインスレッドで
            await MainActor.run {
                isProcessing = false
                if let processedImage = processedImage {
                    // 処理済み画像を設定
                    imageViewModel.updateProcessedImage(processedImage)
                    // 処理済み画像を表示
                    showOriginal = false
                }
            }
        }
    }
    
    // 背景削除処理
    private func removeBackground(from image: UIImage) -> UIImage? {
        return BackgroundRemoval.removeBackground(from: image)
    }
}

// 画像データを管理するViewModel
class ImageViewModel: ObservableObject {
    @Published var imageData: ImageData
    
    init(imageData: ImageData) {
        self.imageData = imageData
    }
    
    // 処理済み画像を更新
    func updateProcessedImage(_ image: UIImage) {
        imageData.processedImage = image
        objectWillChange.send()
    }
} 