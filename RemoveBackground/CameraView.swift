import SwiftUI

struct CameraView: View {
    @StateObject var cameraManager = CameraManager()
    
    var body: some View {
        ZStack {
            if cameraManager.isError {
                // エラー表示
                VStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .frame(width: 80, height: 70)
                        .foregroundColor(.yellow)
                        .padding()
                    
                    Text(cameraManager.errorMessage)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button("設定を開く") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(20)
                .padding(30)
                
            } else if !cameraManager.isTaken {
                CameraPreview(cameraManager: cameraManager)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    Button(action: {
                        cameraManager.takePicture()
                    }) {
                        Image(systemName: "camera.circle.fill")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.white)
                            .padding(.bottom, 40)
                    }
                }
            } else {
                if let image = cameraManager.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                    
                    VStack {
                        Spacer()
                        HStack {
                            Button(action: {
                                cameraManager.retake()
                            }) {
                                Image(systemName: "arrow.triangle.2.circlepath.camera")
                                    .resizable()
                                    .frame(width: 60, height: 50)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal)
                            
                            Button(action: {
                                // ここに背景除去処理を追加予定
                            }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
} 