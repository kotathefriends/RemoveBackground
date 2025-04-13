import SwiftUI

struct ImageViewer: View {
    @ObservedObject var viewModel: ImageViewModel
    @Binding var isPresented: Bool
    @State private var showControls = true
    @State private var selectedImageIndex = 0 // 表示する画像のインデックス
    @State private var contourPath: Path? = nil // 輪郭パスを保持するState

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if showControls {
                    // 画像切り替えインジケーター
                    if viewModel.hasProcessedImage {
                        HStack(spacing: 4) {
                            // 処理済み画像1（輪郭線付き）
                            Rectangle()
                                .fill(selectedImageIndex == 0 ? Color.white : Color.white.opacity(0.5))
                                .frame(height: 3)
                                .onTapGesture {
                                    selectedImageIndex = 0
                                }
                            
                            // 処理済み画像2（白背景）
                            Rectangle()
                                .fill(selectedImageIndex == 1 ? Color.white : Color.white.opacity(0.5))
                                .frame(height: 3)
                                .onTapGesture {
                                    selectedImageIndex = 1
                                }
                            
                            // 元画像
                            Rectangle()
                                .fill(selectedImageIndex == 2 ? Color.white : Color.white.opacity(0.5))
                                .frame(height: 3)
                                .onTapGesture {
                                    selectedImageIndex = 2
                                }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 5)
                    }
                    
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
                
                // 画像表示部分
                GeometryReader { geometry in
                    ZStack {
                        // 選択されたインデックスに応じて画像を表示
                        if viewModel.hasProcessedImage, let processedImage = viewModel.imageData.processedImage {
                            if selectedImageIndex == 0 {
                                // 処理済み画像1（輪郭線付き）
                                ZStack {
                                    // 背景色（白）
                                    Color.white
                                        .aspectRatio(3/4, contentMode: .fit)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                                    // 枠線を描画 (画像よりも下に配置)
                                    if let path = contourPath {
                                        // 画像の表示サイズとコンテナサイズからオフセットを計算
                                        let imageSize = calculateImageDisplaySize(originalSize: processedImage.size, containerSize: geometry.size)
                                        let offsetX = (geometry.size.width - imageSize.width) / 2
                                        let offsetY = (geometry.size.height - imageSize.height) / 2
                                        let width = imageSize.width
                                        let height = imageSize.height

                                        // 変換行列を作成: 単純なスケーリングと平行移動
                                        let transform = CGAffineTransform(a: width, b: 0, c: 0, d: height, tx: offsetX, ty: offsetY)
                                        
                                        // パスを変換して描画
                                        let transformedPath = path.applying(transform)
                                        transformedPath
                                            .stroke(Color.red, lineWidth: 10) // 赤い枠線
                                    }

                                    // 処理済み画像を枠線の上に重ねる
                                    Image(uiImage: processedImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            } else if selectedImageIndex == 1 {
                                // 処理済み画像2（白背景、枠線なし）
                                ZStack {
                                    Color.white
                                        .aspectRatio(3/4, contentMode: .fit)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    
                                    Image(uiImage: processedImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            } else {
                                // 元画像
                                Image(uiImage: viewModel.imageData.originalImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        } else {
                            // 処理済み画像がない場合は元画像を表示
                            Image(uiImage: viewModel.imageData.originalImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        
                        // タップジェスチャーを追加
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if viewModel.hasProcessedImage {
                                    withAnimation {
                                        selectedImageIndex = (selectedImageIndex + 1) % 3
                                    }
                                }
                            }
                            .onLongPressGesture(minimumDuration: 0.3) {
                                withAnimation {
                                    showControls.toggle()
                                }
                            }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                if viewModel.isProcessing && showControls {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.bottom, 30)
                }
            }
        }
        .onChange(of: viewModel.imageData.processedImage) { _, newImage in
            if let image = newImage {
                // 輪郭検出処理を非同期で実行
                Task {
                    if #available(iOS 18.0, *) {
                        self.contourPath = await ContourDetection.detectContours(from: image)
                    } else {
                        print("輪郭検出はiOS 18以降で利用可能です。")
                    }
                }
            } else {
                // processedImageがnilになったらパスもクリア
                self.contourPath = nil
            }
        }
        .onAppear {
            // 画面表示時に自動的に背景削除を開始
            if !viewModel.hasProcessedImage && !viewModel.isProcessing {
                viewModel.removeBackgroundAsync()
            }
            // すでに処理済み画像がある場合にも輪郭検出を試みる
            else if let image = viewModel.imageData.processedImage, contourPath == nil {
                Task {
                    if #available(iOS 18.0, *) {
                        self.contourPath = await ContourDetection.detectContours(from: image)
                    } else {
                        print("輪郭検出はiOS 18以降で利用可能です。")
                    }
                }
            }
        }
    }

    // MARK: - Helper Functions

    /// 画像がコンテナ内でどのように表示されるかを計算するヘルパー関数
    private func calculateImageDisplaySize(originalSize: CGSize, containerSize: CGSize) -> CGSize {
        let aspectRatio = originalSize.width / originalSize.height
        let containerAspectRatio = containerSize.width / containerSize.height

        var displayWidth: CGFloat
        var displayHeight: CGFloat

        if aspectRatio > containerAspectRatio {
            // 画像がコンテナより横長 -> 幅をコンテナに合わせる
            displayWidth = containerSize.width
            displayHeight = displayWidth / aspectRatio
        } else {
            // 画像がコンテナより縦長または同じ比率 -> 高さをコンテナに合わせる
            displayHeight = containerSize.height
            displayWidth = displayHeight * aspectRatio
        }

        return CGSize(width: displayWidth, height: displayHeight)
    }
}
