//
//  RemoveBackgroundApp.swift
//  RemoveBackground
//
//  Created by KOTA TAKAHASHI on 2025/03/15.
//

import SwiftUI
import AVFoundation

@main
struct RemoveBackgroundApp: App {
    init() {
        // カメラ権限を事前にチェック
        checkCameraPermission()
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("カメラアクセス許可済み")
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    print("カメラアクセス許可されました")
                } else {
                    print("カメラアクセス拒否されました")
                }
            }
        case .denied, .restricted:
            print("カメラアクセスが拒否されています")
        @unknown default:
            print("不明なカメラ権限状態")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
