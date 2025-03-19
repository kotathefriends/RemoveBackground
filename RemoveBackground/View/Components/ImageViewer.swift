import SwiftUI

// 画像の輪郭に沿った枠線を追加するためのViewModifier
struct ImageBorderModifier: ViewModifier {
    var color: Color
    var lineWidth: CGFloat
    
    func body(content: Content) -> some View {
        ZStack {
            // 枠線効果（影を使用）- 影付き白枠線
            content
                .shadow(color: color, radius: 0, x: lineWidth, y: 0)
                .shadow(color: color, radius: 0, x: -lineWidth, y: 0)
                .shadow(color: color, radius: 0, x: 0, y: lineWidth)
                .shadow(color: color, radius: 0, x: 0, y: -lineWidth)
                .shadow(color: .black.opacity(0.5), radius: 3, x: 2, y: 2) // 枠線に対する影
            
            // 元の画像
            content
        }
    }
}

// Viewの拡張
extension View {
    func imageBorder(color: Color, lineWidth: CGFloat) -> some View {
        self.modifier(ImageBorderModifier(color: color, lineWidth: lineWidth))
    }
}

struct ImageViewer: View {
    @ObservedObject var viewModel: ImageViewModel
    @Binding var isPresented: Bool
    @State private var showControls = true
    @State private var selectedImageIndex = 0 // 表示する画像のインデックス
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if showControls {
                    // 画像切り替えインジケーター
                    if viewModel.hasProcessedImage {
                        HStack(spacing: 4) {
                            // 処理済み画像1（白背景）
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
                ZStack {
                    // 選択されたインデックスに応じて画像を表示
                    if viewModel.hasProcessedImage {
                        if selectedImageIndex == 0 {
                            // 処理済み画像1（ステッカー風）
                            ZStack {
                                // 背景色
                                Color.white
                                    .aspectRatio(3/4, contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                
                                // ステッカー風の処理済み画像（輪郭に沿った枠線と影）
                                Image(uiImage: viewModel.imageData.processedImage!)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .imageBorder(color: .white, lineWidth: 12) // 白色の枠線を太く(5→8)
                            }
                        } else if selectedImageIndex == 1 {
                            // 処理済み画像2（白背景、枠線なし）
                            ZStack {
                                // 白背景（3:4のアスペクト比）
                                Color.white
                                    .aspectRatio(3/4, contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                
                                // 処理済み画像（枠線なし）
                                Image(uiImage: viewModel.imageData.processedImage!)
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
                
                if viewModel.isProcessing && showControls {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            // 画面表示時に自動的に背景削除を開始
            if !viewModel.hasProcessedImage && !viewModel.isProcessing {
                viewModel.removeBackgroundAsync()
            }
        }
    }
}
