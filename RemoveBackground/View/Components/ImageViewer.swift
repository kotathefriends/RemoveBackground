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
                    HStack(spacing: 4) {
                        if viewModel.hasProcessedImage {
                            Rectangle()
                                .fill(!viewModel.showOriginal ? Color.white : Color.white.opacity(0.5))
                                .frame(height: 3)
                                .onTapGesture {
                                    viewModel.showOriginal = false
                                }
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
                
                Image(uiImage: viewModel.displayImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture {
                        viewModel.toggleImageDisplay()
                    }
                    .onLongPressGesture(minimumDuration: 0.3) {
                        withAnimation {
                            showControls.toggle()
                        }
                    }
                
                Spacer()
                
                if !viewModel.hasProcessedImage && showControls {
                    Button(action: {
                        viewModel.removeBackgroundAsync()
                    }) {
                        HStack {
                            if viewModel.isProcessing {
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
                    .disabled(viewModel.isProcessing)
                    .padding(.bottom, 30)
                }
            }
        }
    }
}
