import SwiftUI

// 写真閲覧ビュー
struct ImageViewer: View {
    let image: UIImage
    @Binding var isPresented: Bool
    @Environment(\.presentationMode) var presentationMode
    @State private var processedImage: UIImage?
    @State private var isProcessing = false
    var showRemoveBackgroundButton: Bool = true
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                // 閉じるボタン
                HStack {
                    Spacer()
                    Button(action: {
                        print("閉じるボタンがタップされました")
                        isPresented = false
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                
                Spacer()
                
                // 画像表示
                if let processedImage = processedImage {
                    Image(uiImage: processedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                Spacer()
                
                // 背景削除ボタン（表示フラグがtrueの場合のみ表示）
                if showRemoveBackgroundButton {
                    Button(action: {
                        removeBackgroundAsync()
                    }) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 5)
                            } else {
                                Image(systemName: "scissors")
                                    .font(.system(size: 16))
                            }
                            Text(isProcessing ? "処理中..." : "背景を削除")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                    .disabled(isProcessing || processedImage != nil)
                    .padding(.bottom, 20)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    private func removeBackgroundAsync() {
        isProcessing = true
        
        Task {
            let result = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let result = removeBackground(from: image)
                    continuation.resume(returning: result)
                }
            }
            
            DispatchQueue.main.async {
                self.processedImage = result
                self.isProcessing = false
            }
        }
    }
} 