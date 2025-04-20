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
    // カメラ権限チェックは不要（CameraManagerで行うため）
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
