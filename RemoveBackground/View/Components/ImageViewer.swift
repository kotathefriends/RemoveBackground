import SwiftUI
import Vision // Visionフレームワークをインポート

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
              // 処理済み画像1（ステッカー風）- Visionで輪郭描画
              GeometryReader { geometry in // サイズ取得
                ZStack {
                  // 背景色 (白)
                  Color.white
                    .aspectRatio(viewModel.imageData.processedImage?.size ?? CGSize(width: 1, height: 1), contentMode: .fit) // 画像のアスペクト比に合わせる
                    .frame(width: geometry.size.width, height: geometry.size.height)
                   
                  // 処理済み画像
                  Image(uiImage: viewModel.imageData.processedImage!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)

                  // 輪郭パスを描画
                  if geometry.size.width > 0 && geometry.size.height > 0 {
                    if let processedImage = viewModel.imageData.processedImage,
                      let cgPath = detectVisionContours(from: processedImage) {
                      let swiftUIPath = createSwiftUIPath(from: cgPath, in: geometry.size)
                      if !swiftUIPath.isEmpty {
                        swiftUIPath
                          .stroke(Color.red, lineWidth: 3) // 境界線の色を赤に変更
                          let _ = print("DEBUG: Border path drawn for index 0 with size \(geometry.size).")
                      } else {
                          let _ = print("DEBUG: SwiftUI Path is empty for index 0 even with size \(geometry.size).")
                      }
                    } else {
                        let _ = print("DEBUG: Contour detection failed or no image for index 0 with size \(geometry.size).")
                    }
                  } else {
                      let _ = print("DEBUG: GeometryReader size is zero, skipping path drawing.")
                  }
                }
              }
              .aspectRatio(viewModel.imageData.processedImage?.size ?? CGSize(width: 1, height: 1), contentMode: .fit)
              .frame(maxWidth: .infinity, maxHeight: .infinity)

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

  // Visionを使って画像の輪郭を検出する関数
  private func detectVisionContours(from sourceImage: UIImage) -> CGPath? {
      print("DEBUG: detectVisionContours - Preparing image for contour detection.")
    // --- 画像の前処理: 白い背景に描画 --- START
    let size = sourceImage.size
    // UIGraphicsImageRendererを使用して白い背景に元画像を描画
    let processedInputImage = UIGraphicsImageRenderer(size: size).image { context in
      // 白い背景で塗りつぶし
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: size))
      // 元画像を描画
      sourceImage.draw(in: CGRect(origin: .zero, size: size))
    }
    // --- 画像の前処理: 白い背景に描画 --- END

    // 前処理した画像のCGImageを取得
    guard let cgImage = processedInputImage.cgImage else {
        print("DEBUG: detectVisionContours - Failed to get cgImage from processed input image.")
      return nil
    }
      print("DEBUG: detectVisionContours - Starting detection for image size: \(processedInputImage.size)")
    let inputImage = CIImage(cgImage: cgImage)

    let contourRequest = VNDetectContoursRequest()
    // revisionを1に設定 (Stack Overflowの成功例に合わせる)
    contourRequest.revision = VNDetectContourRequestRevision1
    contourRequest.contrastAdjustment = 1.5 // コントラストを少し上げてみる（調整可能）
    contourRequest.maximumImageDimension = 512 // 処理負荷を考慮して最大画像サイズを設定

    let requestHandler = VNImageRequestHandler(ciImage: inputImage, options: [:])

    do {
      try requestHandler.perform([contourRequest])
      if let contoursObservation = contourRequest.results?.first,
        contoursObservation.contourCount > 0 {
        // 最初の輪郭 (最も外側であると期待) の normalizedPath を返す
        // より複雑な輪郭構造の場合は contoursObservation.contours を確認する必要がある
          print("DEBUG: detectVisionContours - Contour detection successful.Contour count: \(contoursObservation.contourCount).Path bounding box: \(contoursObservation.normalizedPath.boundingBox)")
        // バウンディングボックスが全体 (0,0,1,1) になっていないか簡易チェック
        if contoursObservation.normalizedPath.boundingBox != CGRect(x: 0, y: 0, width: 1, height: 1) {
          return contoursObservation.normalizedPath
        } else {
            print("DEBUG: detectVisionContours - Warning: Detected path seems to be the full image bounds.")
          // 全体枠が検出された場合も、一旦返してみる (デバッグ用)
           return contoursObservation.normalizedPath
        }
      }
        print("DEBUG: detectVisionContours - No contours found.")
    } catch {
        print("DEBUG: detectVisionContours - Error performing contour detection: \(error.localizedDescription)")
    }

    return nil
  }

  // Visionから得られたCGPathをSwiftUIのPathに変換し、サイズ調整する関数
  private func createSwiftUIPath(from cgPath: CGPath, in size: CGSize) -> Path {
      print("DEBUG: createSwiftUIPath - Converting CGPath (bounding box: \(cgPath.boundingBox)) to fit size: \(size)")
    // normalizedPathは (0,0) から (1,1) の座標系で、Y軸が反転している
    // SwiftUIの座標系 (左上原点) とサイズに合わせて変換する
    let pathBoundingBox = cgPath.boundingBox
    // Avoid division by zero
    guard pathBoundingBox.width > 0, pathBoundingBox.height > 0 else {
        print("DEBUG: createSwiftUIPath - Error: Path bounding box has zero width or height.")
      return Path()
    }
    let scaleX: CGFloat = size.width / pathBoundingBox.width
    let scaleY: CGFloat = size.height / pathBoundingBox.height
      print("DEBUG: createSwiftUIPath - Scale factors: X=\(scaleX), Y=\(scaleY)")

    // --- Y軸反転と平行移動を含むアフィン変換を修正 --- START
    // 目標: Vision座標 (Y=0が底) をSwiftUI座標 (Y=0が天井) にマッピング
    // x_swiftui = x_norm * size.width
    // y_swiftui = size.height - y_norm * size.height
    // アフィン変換パラメータ: a = size.width, d = -size.height, ty = size.height
    var transform = CGAffineTransform(a: size.width, b: 0,
                     c: 0,      d: -size.height,
                     tx: 0,      ty: size.height)

    // 古い変換ロジック (間違い)
    // var transform = CGAffineTransform.identity
    //   .scaledBy(x: 1, y: -1)     // 1. Y軸反転
    //   .translatedBy(x: 0, y: -1.0)  // 2. Y軸を1.0上に移動 (反転後の座標系なので-1.0)
    //   .scaledBy(x: size.width, y: size.height) // 3. 全体を目標サイズにスケーリング
    // --- Y軸反転と平行移動を含むアフィン変換を修正 --- END

    // アフィン変換を適用して新しいCGPathを作成
    if let transformedCGPath = cgPath.copy(using: &transform) {
        print("DEBUG: createSwiftUIPath - Path conversion successful.New bounding box: \(transformedCGPath.boundingBox)")
      return Path(transformedCGPath) // SwiftUIのPathに変換
    } else {
        print("DEBUG: createSwiftUIPath - Failed to apply transform to CGPath.")
      return Path() // 変換に失敗した場合は空のPathを返す
    }
  }
}
