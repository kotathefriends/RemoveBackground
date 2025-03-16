import SwiftUI

struct ImageViewer: View {
    @ObservedObject var viewModel: ImageViewModel
    @Binding var isPresented: Bool
    @State private var showControls = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if showControls {
                    // 元画像/処理済み画像の切り替えインジケーター
                    if viewModel.hasProcessedImage {
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(!viewModel.showOriginal ? Color.white : Color.white.opacity(0.5))
                                .frame(height: 3)
                                .onTapGesture {
                                    viewModel.showOriginal = false
                                }
                            
                            Rectangle()
                                .fill(viewModel.showOriginal ? Color.white : Color.white.opacity(0.5))
                                .frame(height: 3)
                                .onTapGesture {
                                    viewModel.showOriginal = true
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
                
                Spacer()
                
                Image(uiImage: viewModel.displayImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture {
                        // 画像タップで元画像と処理済み画像を切り替え
                        viewModel.toggleImageDisplay()
                    }
                    .onLongPressGesture(minimumDuration: 0.3) {
                        withAnimation {
                            showControls.toggle()
                        }
                    }
                
                Spacer()
                
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
