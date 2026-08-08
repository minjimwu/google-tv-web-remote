import SwiftUI
import UIKit

struct RemoteControlView: View {
    @StateObject private var btManager = BluetoothHIDRemoteManager()
    @State private var showLogs: Bool = true
    
    // Haptic Feedback Generator
    private let hapticImpact = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.05, green: 0.07, blue: 0.12), Color(red: 0.02, green: 0.03, blue: 0.06)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Header Bar
                    headerView
                    
                    // 2. Power & System Top Actions
                    topActionsView
                    
                    // 3. Central D-Pad Navigation
                    dPadView
                    
                    // 4. Navigation Keys (Back, Home, Menu)
                    navigationKeysView
                    
                    // 5. Volume & Channel Rockers
                    rockerControlsView
                    
                    // 6. App Shortcuts
                    appShortcutsView
                    
                    // 7. Number Pad
                    numberPadView
                    
                    // 8. Live Signal Log Viewer
                    if showLogs {
                        consoleLogView
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: 580) // Optimized width for iPad
            }
        }
        .onAppear {
            hapticImpact.prepare()
        }
    }
    
    // MARK: - Subviews
    
    // Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("HERAN")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, Color(red: 0.6, green: 0.75, blue: 1.0)], startPoint: .leading, endPoint: .trailing)
                    )
                Text("Google TV Remote (BLE)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.blue)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Circle()
                    .fill(btManager.isAdvertising ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                    .shadow(color: btManager.isAdvertising ? Color.green : Color.clear, radius: 6)
                
                Text(btManager.statusMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                
                Button(action: {
                    hapticImpact.impactOccurred()
                    btManager.toggleAdvertising()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text(btManager.isAdvertising ? "停止廣播" : "啟動廣播")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(btManager.isAdvertising ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                    .foregroundColor(btManager.isAdvertising ? .red : .blue)
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(btManager.isAdvertising ? Color.red : Color.blue, lineWidth: 1)
                    )
                }
            }
        }
        .padding(.bottom, 8)
        .overlay(Divider().background(Color.white.opacity(0.1)), alignment: .bottom)
    }
    
    // Top Power Row
    private var topActionsView: some View {
        HStack(spacing: 32) {
            Button(action: {
                triggerKey("POWER", code: 0x0030)
            }) {
                Image(systemName: "power")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.red)
                    .frame(width: 60, height: 60)
                    .background(
                        RadialGradient(colors: [Color(red: 0.25, green: 0.08, blue: 0.08), Color(red: 0.12, green: 0.04, blue: 0.04)], center: .center, startRadius: 5, endRadius: 30)
                    )
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.red.opacity(0.6), lineWidth: 1.5))
                    .shadow(color: .red.opacity(0.3), radius: 8)
            }
            
            Spacer()
            
            Button(action: {
                triggerKey("INPUT", code: 0x001B)
            }) {
                Text("INPUT")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }
            
            Button(action: {
                triggerKey("SETTINGS", code: 0x006F)
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }
        }
    }
    
    // D-Pad Navigation
    private var dPadView: some View {
        ZStack {
            // Outer Ring
            Circle()
                .fill(
                    RadialGradient(colors: [Color(red: 0.15, green: 0.18, blue: 0.25), Color(red: 0.08, green: 0.10, blue: 0.14)], center: .center, startRadius: 30, endRadius: 110)
                )
                .frame(width: 230, height: 230)
                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                .shadow(color: .black.opacity(0.6), radius: 12, y: 6)
            
            VStack {
                // UP
                Button(action: { triggerKey("DPAD_UP", code: 0x0042) }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 50)
                }
                
                Spacer()
                
                // DOWN
                Button(action: { triggerKey("DPAD_DOWN", code: 0x0043) }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 50)
                }
            }
            .frame(height: 210)
            
            HStack {
                // LEFT
                Button(action: { triggerKey("DPAD_LEFT", code: 0x0044) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 60)
                }
                
                Spacer()
                
                // RIGHT
                Button(action: { triggerKey("DPAD_RIGHT", code: 0x0045) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 60)
                }
            }
            .frame(width: 210)
            
            // CENTER OK BUTTON
            Button(action: { triggerKey("DPAD_CENTER", code: 0x0041) }) {
                Text("OK")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 76, height: 76)
                    .background(
                        LinearGradient(colors: [Color(red: 0.15, green: 0.35, blue: 0.65), Color(red: 0.08, green: 0.20, blue: 0.40)], startPoint: .top, endPoint: .bottom)
                    )
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.blue, lineWidth: 1.5))
                    .shadow(color: .blue.opacity(0.4), radius: 8)
            }
        }
        .padding(.vertical, 8)
    }
    
    // Navigation Keys
    private var navigationKeysView: some View {
        HStack(spacing: 40) {
            Button(action: { triggerKey("BACK", code: 0x0224) }) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.backward")
                        .font(.system(size: 20, weight: .bold))
                    Text("返回")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
            }
            
            Button(action: { triggerKey("HOME", code: 0x0223) }) {
                VStack(spacing: 4) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 22, weight: .bold))
                    Text("主頁")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.blue)
                .frame(width: 64, height: 64)
                .background(Color.blue.opacity(0.15))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.blue.opacity(0.4), lineWidth: 1))
            }
            
            Button(action: { triggerKey("MENU", code: 0x0040) }) {
                VStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .bold))
                    Text("選單")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
            }
        }
    }
    
    // Rocker Controls
    private var rockerControlsView: some View {
        HStack(spacing: 20) {
            // VOL Rocker Card
            VStack(spacing: 12) {
                Text("VOL")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                
                Button(action: { triggerKey("VOLUME_UP", code: 0x00E9) }) {
                    Text("+")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Button(action: { triggerKey("MUTE", code: 0x00E2) }) {
                    Image(systemName: "speaker.slash.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.red)
                        .frame(width: 40, height: 40)
                        .background(Color.red.opacity(0.15))
                        .clipShape(Circle())
                }
                
                Button(action: { triggerKey("VOLUME_DOWN", code: 0x00EA) }) {
                    Text("-")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1))
            
            // CH Rocker Card
            VStack(spacing: 12) {
                Text("CH")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                
                Button(action: { triggerKey("CHANNEL_UP", code: 0x009C) }) {
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Text("CH")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(height: 40)
                
                Button(action: { triggerKey("CHANNEL_DOWN", code: 0x009D) }) {
                    Image(systemName: "triangle.fill")
                        .rotationEffect(.degrees(180))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }
    
    // App Shortcuts
    private var appShortcutsView: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            Button(action: { triggerKey("APP_YOUTUBE", code: 0x0077) }) {
                Text("YouTube")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.4), lineWidth: 1))
            }
            
            Button(action: { triggerKey("APP_NETFLIX", code: 0x0078) }) {
                Text("NETFLIX")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(Color(red: 0.9, green: 0.05, blue: 0.1))
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.3), lineWidth: 1))
            }
            
            Button(action: { triggerKey("APP_PRIME", code: 0x0079) }) {
                Text("prime video")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.cyan)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Color.cyan.opacity(0.12))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan.opacity(0.4), lineWidth: 1))
            }
            
            Button(action: { triggerKey("APP_HERAN", code: 0x007A) }) {
                Text("HERAN TV")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.4), lineWidth: 1))
            }
        }
    }
    
    // Number Pad
    private var numberPadView: some View {
        VStack(spacing: 8) {
            Text("數字鍵盤")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            
            let numMap: [(String, UInt16)] = [
                ("1", 0x001E), ("2", 0x001F), ("3", 0x0020),
                ("4", 0x0021), ("5", 0x0022), ("6", 0x0023),
                ("7", 0x0024), ("8", 0x0025), ("9", 0x0026),
                ("INFO", 0x0035), ("0", 0x0027), ("⌫", 0x002A)
            ]
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(numMap, id: \.0) { item in
                    Button(action: { triggerKey(item.0, code: item.1) }) {
                        Text(item.0)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.03))
        .cornerRadius(20)
    }
    
    // Console Log Viewer
    private var consoleLogView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("藍芽訊號日誌 (BLE Output)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Button("清除") {
                    btManager.logs.removeAll()
                }
                .font(.system(size: 11))
                .foregroundColor(.blue)
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(btManager.logs.enumerated()), id: \.offset) { index, logText in
                            Text(logText)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(logText.contains("發送") ? .green : .secondary)
                                .id(index)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 70)
                .onChange(of: btManager.logs.count) { _ in
                    if let lastIndex = btManager.logs.indices.last {
                        proxy.scrollTo(lastIndex, anchor: .bottom)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.6))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    // Trigger Key Action
    private func triggerKey(_ name: String, code: UInt16) {
        hapticImpact.impactOccurred()
        btManager.sendKeyCommand(name, reportValue: code)
    }
}

#Preview {
    RemoteControlView()
}
